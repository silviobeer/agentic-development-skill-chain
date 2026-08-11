#!/usr/bin/env node
// render-report.mjs — deterministic report rendering (CONCEPT.md §8).
//
// Two modes, both pure renders from state.json + findings.json:
//
//   morning [specs-dir]
//     Scans <specs-dir>/PROJ-*/state.json, renders the morning report to
//     <specs-dir>/morning-report-<date>.md and prints the one-liner for
//     the best-effort push notification to stdout.
//
//   stop <proj-x> <theme> --reason "<text>" [--error-file <path>]
//     Renders specs/PROJ-<X>-<theme>/5_progress/stop-report.md.
//
// Exit: 0 ok · 1 render failed · 2 required input missing · 64 usage
import { readFileSync, writeFileSync, existsSync, readdirSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const tmpl = (name) => readFileSync(join(here, "templates", name), "utf8");
const today = new Date().toISOString().slice(0, 10);
const now = new Date().toISOString();

const usage = () => {
  console.error(
    "Usage: render-report.mjs morning [specs-dir]\n" +
    "       render-report.mjs stop <proj-x> <theme> --reason <text> [--error-file <path>]",
  );
  process.exit(64);
};

const readJson = (p) => JSON.parse(readFileSync(p, "utf8"));
const shellQuote = (value) => `'${String(value).replaceAll("'", `'"'"'`)}'`;
const safeP8Resume = (s) => {
  if (!s.worktree?.path) return null;
  const projX = String(s.proj ?? "").replace(/^PROJ-/, "");
  if (!/^\d+$/.test(projX) || typeof s.theme !== "string") return null;
  return `(cd ${shellQuote(s.worktree.path)} && ${shellQuote(join(here, "run-phase.sh"))} P8 ${shellQuote(projX)} ${shellQuote(s.theme)})`;
};
const fill = (template, values) => {
  let out = template;
  for (const [k, v] of Object.entries(values)) out = out.replaceAll(`{{${k}}}`, () => String(v));
  const left = out.match(/{{[A-Z_]+}}/g);
  if (left) { console.error(`render-report.mjs: unreplaced placeholders: ${[...new Set(left)].join(", ")}`); process.exit(1); }
  return out;
};

const findingsFor = (base) =>
  existsSync(join(base, "findings.json")) ? readJson(join(base, "findings.json")).findings : [];

const [mode, ...rest] = process.argv.slice(2);

if (mode === "morning") {
  const specsDir = rest[0] ?? "specs";
  if (!existsSync(specsDir)) { console.error(`render-report.mjs: ${specsDir} missing`); process.exit(2); }

  const projDirs = readdirSync(specsDir)
    .filter((d) => /^PROJ-\d+-/.test(d) && existsSync(join(specsDir, d, "state.json")))
    .sort();
  if (projDirs.length === 0) { console.error(`render-report.mjs: no PROJ-*/state.json under ${specsDir}`); process.exit(2); }

  let prs = 0, stops = 0, done = 0;
  const blocks = projDirs.map((dir) => {
    const base = join(specsDir, dir);
    const s = readJson(join(base, "state.json"));
    const f = findingsFor(base);
    const deferred = f.filter((x) => x.status === "deferred");
    const openBlocking = f.filter((x) => x.status === "open" && (x.severity === "critical" || x.severity === "high"));
    const gaps = Object.entries(s.waves?.stories ?? {}).filter(([, st]) => st === "gap");
    const wt = s.worktree;
    const cleanupDisplay = wt?.cleanup_status === "removed" && existsSync(wt.path)
      ? "removal sealed; awaiting guarded cleanup"
      : (wt?.cleanup_status ?? "pending");
    if (s.pr?.url) prs++;
    if (s.status === "blocked") stops++;
    if (s.phase === "P8" && s.status === "done" || s.phase === "done") done++;

    const lines = [
      `## ${s.proj} (${s.theme}) — ${s.phase}:${s.status}`,
      "",
      s.pr?.url ? `- **PR:** ${s.pr.url} (CI: ${s.pr.ci ?? "unknown"})` : "- **PR:** not created",
      `- **Waves:** ${s.waves?.current ?? "—"}/${s.waves?.total ?? "—"}`,
      "- **Wave-gate scope:** current ACs plus each wave's declared broad regressions; earlier AC commands are not implicitly rerun",
      `- **Findings:** ${f.length} total · ${openBlocking.length} open blocking · ${deferred.length} deferred debt`,
      `- **Known gaps:** ${gaps.length ? gaps.map(([us]) => us).join(", ") : "none"}`,
      wt
        ? `- **Worktree:** \`${wt.path}\` (${cleanupDisplay}${wt.cleanup_reason ? ` — ${wt.cleanup_reason}` : ""})`
        : "- **Worktree:** not recorded",
      wt
        ? `- **Isolation:** dependencies ${wt.dependency_install ?? "unknown"}; .env.local ${wt.env_link_status ?? "unknown"}; database/auth infrastructure shared; dev port ${wt.dev_port ?? "—"}`
        : "- **Isolation:** legacy run",
      s.degraded
        ? `- **Degradation:** ⚠ single-provider run (${s.degraded_reason ?? "codex unavailable"}) — cross-review: model-opposite fallback`
        : "- **Degradation:** none",
    ];
    if (s.status === "blocked") {
      lines.push(`- **STOPPED:** ${s.stop?.reason ?? "unknown"} — report: ${s.stop?.report ?? "missing"}`);
      if (s.stop?.rescue_branch) lines.push(`- **Cleanup:** rescue branch \`${s.stop.rescue_branch}\` to inspect/merge/delete`);
    }
    if (wt?.cleanup_status === "retained") {
      const retry = safeP8Resume(s);
      lines.push(retry
        ? `- **Safe cleanup resume (reseals, pushes, and re-polls exact HEAD):** \`${retry}\``
        : "- **Cleanup:** resume through P8 and obtain final green CI before running the guarded worktree helper");
    }
    if (deferred.length) {
      lines.push("", "  Deferred debt (decide at CP2):");
      for (const d of deferred) lines.push(`  - ${d.id} [${d.severity}] ${d.file ?? ""} — ${d.summary}`);
    }
    return lines.join("\n");
  });

  const oneliner = `${projDirs.length} PROJ(s): ${done} done, ${prs} PR(s) open, ${stops} stop report(s)`;
  const out = fill(tmpl("morning-report.md.tmpl"), {
    DATE: today,
    ONELINER: `**${oneliner}**`,
    PROJS: blocks.join("\n\n"),
  });
  const outPath = join(specsDir, `morning-report-${today}.md`);
  writeFileSync(outPath, out);
  console.log(oneliner);
  console.log(`report: ${outPath}`);
} else if (mode === "stop") {
  const [projX, theme] = rest;
  if (!projX || !theme) usage();
  const reasonIdx = rest.indexOf("--reason");
  if (reasonIdx < 0 || !rest[reasonIdx + 1]) usage();
  const reason = rest[reasonIdx + 1];
  const errIdx = rest.indexOf("--error-file");
  const errFile = errIdx >= 0 ? rest[errIdx + 1] : null;

  const base = `specs/PROJ-${projX}-${theme}`;
  if (!existsSync(join(base, "state.json"))) { console.error(`render-report.mjs: ${base}/state.json missing`); process.exit(2); }
  const s = readJson(join(base, "state.json"));
  const cleanupDisplay = s.worktree?.cleanup_status === "removed" && existsSync(s.worktree.path)
    ? "removal sealed; awaiting guarded cleanup"
    : (s.worktree?.cleanup_status ?? "pending");

  let errorOutput = "(no captured output)";
  if (errFile && existsSync(errFile)) {
    const raw = readFileSync(errFile, "utf8").split("\n");
    errorOutput = raw.slice(-120).join("\n").trim() || errorOutput;
  }

  const lanes = (s.lanes ?? []).slice(-4).map(
    (l) => `- lane ${l.provider}/${l.role} (${l.phase}): exit ${l.exit_code ?? "running?"} — output: ${l.output_file ?? "—"}`,
  );
  const stateSummary = [
    `- Phase/status: ${s.phase}:${s.status}`,
    `- Branch: \`${s.branch ?? "—"}\` (base ${s.base_sha ?? "—"})`,
    s.worktree
      ? `- Worktree: \`${s.worktree.path}\` from control \`${s.worktree.control_path}\` (${cleanupDisplay}${s.worktree.cleanup_reason ? ` — ${s.worktree.cleanup_reason}` : ""})`
      : "- Worktree: not recorded (legacy run)",
    s.worktree
      ? `- Isolation: dependencies ${s.worktree.dependency_install ?? "unknown"}; .env.local ${s.worktree.env_link_status ?? "unknown"}; database/auth infrastructure shared; dev port ${s.worktree.dev_port ?? "—"}`
      : null,
    `- Waves: ${s.waves?.current ?? "—"}/${s.waves?.total ?? "—"}; stories: ${
      Object.entries(s.waves?.stories ?? {}).map(([us, st]) => `${us}=${st}`).join(", ") || "—"
    }`,
    ...lanes,
  ].filter(Boolean).join("\n");

  const cleanup = [
    s.stop?.rescue_branch ? `- Rescue branch \`${s.stop.rescue_branch}\`: inspect, salvage, delete` : null,
    `- Lane output files under \`${base}/5_progress/lanes/\`: review, then remove`,
    s.worktree?.path
      ? (safeP8Resume(s)
          ? `- Retained PROJ worktree \`${s.worktree.path}\`: after resolving the stop, resume P8 (reseal, push, exact-head CI, guarded cleanup) with \`${safeP8Resume(s)}\``
          : `- Retained PROJ worktree \`${s.worktree.path}\`: resume through P8 and obtain final green CI before running \`scripts/worktree.sh cleanup\``)
      : "- Open worktrees / dev servers (if any): documented above — evidence, do not delete before reading",
  ].filter(Boolean).join("\n");

  const out = fill(tmpl("stop-report.md.tmpl"), {
    PROJ: s.proj,
    THEME: s.theme,
    DATE: now,
    PHASE_STATUS: `${s.phase}:${s.status}`,
    REASON: reason,
    ERROR_OUTPUT: errorOutput,
    STATE_SUMMARY: stateSummary,
    CLEANUP: cleanup,
    NEXT_ACTION:
      `Fix the stop cause, then resume with ` +
      `\`bash scripts/state.sh transition ${projX} ${theme} ${s.phase} running\` ` +
      `and re-run \`runner/run-phase.sh ${s.phase} ${projX} ${theme}\`.`,
  });

  mkdirSync(join(base, "5_progress"), { recursive: true });
  const outPath = join(base, "5_progress", "stop-report.md");
  writeFileSync(outPath, out);
  console.log(`stop report: ${outPath}`);
} else {
  usage();
}
