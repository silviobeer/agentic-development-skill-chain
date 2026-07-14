#!/usr/bin/env node
// ledger.mjs — the SOLE write path to specs/PROJ-<X>-<theme>/findings.json.
//
// ONE deduplicated findings ledger per PROJ (CONCEPT.md §7): CodeRabbit,
// Sonar, code review, QA, merge gate, cross-review, CI, and debt markers
// all flow in here. The PR body, debt section, and reports are rendered
// FROM this file — never maintained by hand. Plain node, no dependencies.
//
// Usage:
//   node ledger.mjs add            <proj-x> <theme> [--wave N]    read raw findings as JSON lines on stdin, dedupe + merge
//   node ledger.mjs set-status     <proj-x> <theme> <id> <status> [fix-commit]
//   node ledger.mjs record-attempt <proj-x> <theme> <id>          count a fix ATTEMPT (before dispatch; basis of the 3-attempt stop rule)
//   node ledger.mjs auto-defer     <proj-x> <theme>               open medium/low -> deferred (autonomy policy §8)
//   node ledger.mjs queue          <proj-x> <theme>               open critical/high clustered by file (fix queue, JSON)
//   node ledger.mjs stats          <proj-x> <theme>               counts by severity/status (JSON)
//
// Raw input record (one JSON object per line):
//   required: source, severity, summary
//   optional: category, file, line, anchor, provider, wave, status, debt_marker
//
// Dedupe key: file | anchor-or-line | category (case-insensitive). A re-reported
// finding merges (sources appended, severity escalated) instead of duplicating.
// A re-report with status open REOPENS a previously `fixed` finding — a repair
// that did not survive re-verification must not stay green. `deferred` and
// `false-positive` are deliberate triage decisions and are NOT reopened by
// re-reports. fix_attempts counts dispatched ATTEMPTS (record-attempt), not
// successes, so the §8 three-attempt stop rule is enforceable.
//
// Concurrency: every mutation takes a lock directory next to findings.json
// (atomic mkdir; stale locks older than 30s are stolen), so parallel
// collection streams cannot lose each other's writes.
//
// Exit codes: 0 ok · 1 invalid input / unknown severity / lock timeout (nothing written) · 2 findings.json missing · 64 usage
import { readFileSync, writeFileSync, existsSync, renameSync, mkdirSync, rmdirSync, statSync } from "node:fs";
import { join, dirname } from "node:path";

const SEVERITY_MAP = {
  blocker: "critical", critical: "critical",
  major: "high", high: "high",
  medium: "medium", moderate: "medium",
  minor: "low", low: "low", info: "low", note: "low", advisory: "low",
};
const SEVERITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3 };
const STATUSES = ["open", "fixed", "deferred", "false-positive"];
const SOURCES = ["coderabbit", "sonar", "review", "qa", "merge-gate", "cross-review", "ci", "debt"];

function usage() {
  console.error(
    "Usage: ledger.mjs <add|set-status|record-attempt|auto-defer|queue|stats> <proj-x> <theme> [args]\n" +
    "  add            [--wave N]   (raw findings as JSON lines on stdin)\n" +
    "  set-status     <id> <open|fixed|deferred|false-positive> [fix-commit]\n" +
    "  record-attempt <id>\n" +
    "  auto-defer | queue | stats",
  );
  process.exit(64);
}

const [cmd, projX, theme, ...rest] = process.argv.slice(2);
if (!cmd || !projX || !theme) usage();

const proj = `PROJ-${projX}`;
const base = `specs/${proj}-${theme}`;
const file = join(base, "findings.json");
const now = new Date().toISOString();

function fail(msg) { console.error(`ledger.mjs: ${msg}`); process.exit(1); }

const sleepMs = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);

// Mutations run under a lock directory: mkdir is atomic, so concurrent
// writers serialize instead of overwriting each other's read-modify-write.
function withLock(fn) {
  const lock = join(base, ".findings.lock");
  const deadline = Date.now() + 15000;
  for (;;) {
    try { mkdirSync(lock); break; }
    catch (e) {
      if (e.code === "ENOENT") fail(`${base} does not exist — wrong proj/theme?`);
      try {
        if (Date.now() - statSync(lock).mtimeMs > 30000) { rmdirSync(lock); continue; }
      } catch { /* lock vanished between check and stat — retry */ }
      if (Date.now() > deadline) fail("could not acquire ledger lock within 15s (stale run?)");
      sleepMs(25);
    }
  }
  try { return fn(); } finally { try { rmdirSync(lock); } catch { /* already released */ } }
}

function load({ mustExist = false } = {}) {
  if (!existsSync(file)) {
    if (mustExist) { console.error(`ledger.mjs: ${file} missing`); process.exit(2); }
    return { proj, updated_at: now, findings: [] };
  }
  return JSON.parse(readFileSync(file, "utf8"));
}

// Every record must satisfy the findings.schema.json contract before it
// reaches disk — an agent writing a malformed record fails loudly at write
// time, not silently at render time.
function validateLedger(ledger) {
  if (!/^PROJ-\d+$/.test(ledger.proj ?? "")) fail(`invalid ledger proj '${ledger.proj}' — nothing written`);
  if (!Array.isArray(ledger.findings)) fail("ledger findings is not an array — nothing written");
  for (const f of ledger.findings) {
    for (const req of ["id", "source", "severity", "status", "category", "summary", "created_at"])
      if (!f[req]) fail(`invalid record '${f.id ?? "?"}': missing ${req} — nothing written`);
    if (!(f.severity in SEVERITY_ORDER)) fail(`invalid record '${f.id}': severity '${f.severity}' — nothing written`);
    if (!STATUSES.includes(f.status)) fail(`invalid record '${f.id}': status '${f.status}' — nothing written`);
  }
}

function save(ledger) {
  ledger.updated_at = now;
  validateLedger(ledger);
  const tmp = join(dirname(file), `.findings.${process.pid}.tmp`);
  writeFileSync(tmp, JSON.stringify(ledger, null, 2) + "\n");
  renameSync(tmp, file);
}

const dedupeKey = (f) =>
  [f.file ?? "", f.anchor ?? (f.line != null ? String(f.line) : ""), f.category ?? "general"]
    .join("|").toLowerCase();

const nextId = (findings) => {
  const max = findings.reduce((m, f) => {
    const n = Number((f.id ?? "").split("-").pop());
    return Number.isFinite(n) && n > m ? n : m;
  }, 0);
  return `F-${proj}-${String(max + 1).padStart(3, "0")}`;
};

function findOrFail(ledger, id) {
  const f = ledger.findings.find((x) => x.id === id);
  if (!f) fail(`no finding with id '${id}'`);
  return f;
}

if (cmd === "add") {
  const waveIdx = rest.indexOf("--wave");
  const wave = waveIdx >= 0 ? Number(rest[waveIdx + 1]) : undefined;
  const raw = readFileSync(0, "utf8");
  const lines = raw.split("\n").map((l) => l.trim()).filter(Boolean);

  // Parse and validate BEFORE taking the lock, so bad input cannot stall writers.
  const incomingRecords = lines.map((line) => {
    let rec;
    try { rec = JSON.parse(line); } catch { fail(`not valid JSON: ${line}`); }
    for (const req of ["source", "severity", "summary"])
      if (!rec[req]) fail(`missing required field '${req}': ${line}`);
    if (!SOURCES.includes(rec.source)) fail(`unknown source '${rec.source}' (known: ${SOURCES.join(", ")})`);
    const severity = SEVERITY_MAP[String(rec.severity).toLowerCase()];
    if (!severity) fail(`unknown severity '${rec.severity}' (mapping table in ledger.mjs)`);
    const status = rec.status ?? "open";
    if (!STATUSES.includes(status)) fail(`unknown status '${rec.status}'`);
    return {
      source: rec.source, severity, status,
      category: rec.category ?? "general", summary: rec.summary,
      ...(rec.file && { file: rec.file }),
      ...(rec.line != null && { line: Number(rec.line) }),
      ...(rec.anchor && { anchor: rec.anchor }),
      ...(rec.provider && { provider: rec.provider }),
      ...(rec.debt_marker && { debt_marker: rec.debt_marker }),
      ...(wave != null && { wave }),
    };
  });

  withLock(() => {
    const ledger = load();
    const byKey = new Map(ledger.findings.map((f) => [dedupeKey(f), f]));
    let added = 0, merged = 0, reopened = 0, changed = false;

    for (const incoming of incomingRecords) {
      const existing = byKey.get(dedupeKey(incoming));
      if (existing) {
        const sources = existing.sources ?? [existing.source];
        if (!sources.includes(incoming.source)) {
          existing.sources = [...sources, incoming.source];
          existing.updated_at = now;
          changed = true;
        }
        if (SEVERITY_ORDER[incoming.severity] < SEVERITY_ORDER[existing.severity]) {
          existing.severity = incoming.severity;
          existing.updated_at = now;
          changed = true;
        }
        // A fresh OPEN report against a `fixed` finding means the repair did
        // not survive re-verification — reopen it. deferred/false-positive
        // are deliberate triage decisions and stay untouched.
        if (existing.status === "fixed" && incoming.status === "open") {
          existing.status = "open";
          existing.updated_at = now;
          reopened++;
          changed = true;
        }
        merged++;
      } else {
        const record = { id: nextId(ledger.findings), ...incoming, fix_attempts: 0, created_at: now };
        ledger.findings.push(record);
        byKey.set(dedupeKey(record), record);
        added++; changed = true;
      }
    }

    if (changed) save(ledger);
    const reopenNote = reopened > 0 ? `, ${reopened} REOPENED (fix did not survive re-report)` : "";
    console.log(`ledger.mjs: ${added} added, ${merged} deduped${reopenNote} (${ledger.findings.length} total)`);
  });
} else if (cmd === "set-status") {
  const [id, status, fixCommit] = rest;
  if (!id || !STATUSES.includes(status)) usage();
  withLock(() => {
    const ledger = load({ mustExist: true });
    const f = findOrFail(ledger, id);
    f.status = status;
    f.updated_at = now;
    if (fixCommit) f.fix_commit = fixCommit;
    save(ledger);
    console.log(`ledger.mjs: ${id} -> ${status}`);
  });
} else if (cmd === "record-attempt") {
  const [id] = rest;
  if (!id) usage();
  withLock(() => {
    const ledger = load({ mustExist: true });
    const f = findOrFail(ledger, id);
    f.fix_attempts = (f.fix_attempts ?? 0) + 1;
    f.updated_at = now;
    save(ledger);
    console.log(`ledger.mjs: ${id} fix_attempts=${f.fix_attempts}${f.fix_attempts >= 3 ? " — 3-attempt cap reached: stop condition on next failure (§8)" : ""}`);
  });
} else if (cmd === "auto-defer") {
  withLock(() => {
    const ledger = load({ mustExist: true });
    let n = 0;
    for (const f of ledger.findings) {
      if (f.status === "open" && (f.severity === "medium" || f.severity === "low")) {
        f.status = "deferred";
        f.updated_at = now;
        n++;
      }
    }
    if (n > 0) save(ledger);
    console.log(`ledger.mjs: ${n} medium/low findings auto-deferred (decided at Checkpoint 2, not mid-run)`);
  });
} else if (cmd === "queue") {
  const ledger = load({ mustExist: true });
  const open = ledger.findings.filter(
    (f) => f.status === "open" && (f.severity === "critical" || f.severity === "high"),
  );
  const clusters = new Map();
  for (const f of open) {
    const k = f.file ?? "(no file)";
    if (!clusters.has(k)) clusters.set(k, []);
    clusters.get(k).push(f);
  }
  const queue = [...clusters.entries()]
    .map(([fileKey, findings]) => ({
      file: fileKey,
      max_severity: findings.reduce((m, f) => (SEVERITY_ORDER[f.severity] < SEVERITY_ORDER[m] ? f.severity : m), "high"),
      findings: findings.map((f) => f.id),
    }))
    .sort((a, b) => SEVERITY_ORDER[a.max_severity] - SEVERITY_ORDER[b.max_severity] || a.file.localeCompare(b.file));
  console.log(JSON.stringify(queue, null, 2));
} else if (cmd === "stats") {
  const ledger = load({ mustExist: true });
  const count = (fn) =>
    ledger.findings.reduce((acc, f) => { const k = fn(f); acc[k] = (acc[k] ?? 0) + 1; return acc; }, {});
  const stats = {
    total: ledger.findings.length,
    by_severity: count((f) => f.severity),
    by_status: count((f) => f.status),
    open_blocking: ledger.findings.filter(
      (f) => f.status === "open" && (f.severity === "critical" || f.severity === "high"),
    ).length,
  };
  console.log(JSON.stringify(stats, null, 2));
} else {
  usage();
}
