#!/usr/bin/env node
// ledger.mjs — the SOLE write path to specs/PROJ-<X>-<theme>/findings.json.
//
// ONE deduplicated findings ledger per PROJ (CONCEPT.md §7): CodeRabbit,
// Sonar, code review, QA, merge gate, cross-review, CI, and debt markers
// all flow in here. The PR body, debt section, and reports are rendered
// FROM this file — never maintained by hand. Plain node, no dependencies.
//
// Usage:
//   node ledger.mjs add        <proj-x> <theme> [--wave N]      read raw findings as JSON lines on stdin, dedupe + merge
//   node ledger.mjs set-status <proj-x> <theme> <id> <status> [fix-commit]
//   node ledger.mjs auto-defer <proj-x> <theme>                 open medium/low -> deferred (autonomy policy §8)
//   node ledger.mjs queue      <proj-x> <theme>                 open critical/high clustered by file (fix queue, JSON)
//   node ledger.mjs stats      <proj-x> <theme>                 counts by severity/status (JSON)
//
// Raw input record (one JSON object per line):
//   required: source, severity, summary
//   optional: category, file, line, anchor, provider, wave, status, debt_marker
//
// Dedupe key: file | anchor-or-line | category (case-insensitive). A re-reported
// finding merges (sources appended, severity escalated) instead of duplicating;
// re-running the same input is a no-op (idempotent).
//
// Exit codes: 0 ok · 1 invalid input / unknown severity (nothing written) · 2 findings.json missing · 64 usage
import { readFileSync, writeFileSync, existsSync, renameSync } from "node:fs";
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
    "Usage: ledger.mjs <add|set-status|auto-defer|queue|stats> <proj-x> <theme> [args]\n" +
    "  add        [--wave N]   (raw findings as JSON lines on stdin)\n" +
    "  set-status <id> <open|fixed|deferred|false-positive> [fix-commit]\n" +
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

function load({ mustExist = false } = {}) {
  if (!existsSync(file)) {
    if (mustExist) { console.error(`ledger.mjs: ${file} missing`); process.exit(2); }
    return { proj, updated_at: now, findings: [] };
  }
  return JSON.parse(readFileSync(file, "utf8"));
}

function save(ledger) {
  ledger.updated_at = now;
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

if (cmd === "add") {
  const waveIdx = rest.indexOf("--wave");
  const wave = waveIdx >= 0 ? Number(rest[waveIdx + 1]) : undefined;
  const raw = readFileSync(0, "utf8");
  const lines = raw.split("\n").map((l) => l.trim()).filter(Boolean);

  const ledger = load();
  const byKey = new Map(ledger.findings.map((f) => [dedupeKey(f), f]));
  let added = 0, merged = 0, changed = false;

  for (const line of lines) {
    let rec;
    try { rec = JSON.parse(line); } catch { fail(`not valid JSON: ${line}`); }
    for (const req of ["source", "severity", "summary"])
      if (!rec[req]) fail(`missing required field '${req}': ${line}`);
    if (!SOURCES.includes(rec.source)) fail(`unknown source '${rec.source}' (known: ${SOURCES.join(", ")})`);
    const severity = SEVERITY_MAP[String(rec.severity).toLowerCase()];
    if (!severity) fail(`unknown severity '${rec.severity}' (mapping table in ledger.mjs)`);
    const status = rec.status ?? "open";
    if (!STATUSES.includes(status)) fail(`unknown status '${rec.status}'`);

    const incoming = {
      source: rec.source, severity, status,
      category: rec.category ?? "general", summary: rec.summary,
      ...(rec.file && { file: rec.file }),
      ...(rec.line != null && { line: Number(rec.line) }),
      ...(rec.anchor && { anchor: rec.anchor }),
      ...(rec.provider && { provider: rec.provider }),
      ...(rec.debt_marker && { debt_marker: rec.debt_marker }),
      ...(wave != null && { wave }),
    };

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
      merged++;
    } else {
      const record = { id: nextId(ledger.findings), ...incoming, fix_attempts: 0, created_at: now };
      ledger.findings.push(record);
      byKey.set(dedupeKey(record), record);
      added++; changed = true;
    }
  }

  if (changed) save(ledger);
  console.log(`ledger.mjs: ${added} added, ${merged} deduped (${ledger.findings.length} total)`);
} else if (cmd === "set-status") {
  const [id, status, fixCommit] = rest;
  if (!id || !STATUSES.includes(status)) usage();
  const ledger = load({ mustExist: true });
  const f = ledger.findings.find((x) => x.id === id);
  if (!f) fail(`no finding with id '${id}'`);
  f.status = status;
  f.updated_at = now;
  if (status === "fixed") f.fix_attempts = (f.fix_attempts ?? 0) + 1;
  if (fixCommit) f.fix_commit = fixCommit;
  save(ledger);
  console.log(`ledger.mjs: ${id} -> ${status}`);
} else if (cmd === "auto-defer") {
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
