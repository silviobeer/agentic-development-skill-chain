#!/usr/bin/env node
// render-pr-body.mjs — P8 step 3: render the PR description from data.
//
// Pure render, no side effects (CONCEPT.md §7 script specs): reads
// state.json + findings.json + the template and prints the PR body to
// stdout. The LLM never freehands the PR body — free text enters only
// through structured state fields (.summary, .docs_changed) that this
// renderer places inside the fixed frame. Same data in → byte-identical
// structure out.
//
// Usage: render-pr-body.mjs <proj-x> <theme> [template-path]
//        template-path defaults to templates/pr-body.md.tmpl, falling
//        back to the template shipped next to this script.
// Exit:  0 ok · 1 render failed · 2 state.json/findings.json missing · 64 usage
import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const [projX, theme, templateArg] = process.argv.slice(2);
if (!projX || !theme) {
  console.error("Usage: render-pr-body.mjs <proj-x> <theme> [template-path]");
  process.exit(64);
}

const base = `specs/PROJ-${projX}-${theme}`;
const here = dirname(fileURLToPath(import.meta.url));
const templatePath =
  templateArg ??
  (existsSync("templates/pr-body.md.tmpl")
    ? "templates/pr-body.md.tmpl"
    : join(here, "..", "templates", "pr-body.md.tmpl"));

for (const f of [`${base}/state.json`, templatePath]) {
  if (!existsSync(f)) { console.error(`render-pr-body.mjs: ${f} missing`); process.exit(2); }
}

const state = JSON.parse(readFileSync(`${base}/state.json`, "utf8"));
const findings = existsSync(`${base}/findings.json`)
  ? JSON.parse(readFileSync(`${base}/findings.json`, "utf8")).findings
  : [];

const count = (pred) => findings.filter(pred).length;
const stories = Object.entries(state.waves?.stories ?? {});

const storiesBlock = stories.length
  ? stories.map(([us, st]) => `- ${us}: ${st}`).join("\n")
  : "_no per-story status recorded_";

const gateSummary = [
  `- Waves: ${state.waves?.current ?? "?"}/${state.waves?.total ?? "?"} complete`,
  `- Findings: ${findings.length} total — ` +
    `${count((f) => f.status === "fixed")} fixed, ` +
    `${count((f) => f.status === "deferred")} deferred, ` +
    `${count((f) => f.status === "false-positive")} false-positive, ` +
    `${count((f) => f.status === "open")} open`,
  `- Open blocking (critical/high): ${count((f) => f.status === "open" && (f.severity === "critical" || f.severity === "high"))}`,
].join("\n");

const gaps = stories.filter(([, st]) => st === "gap").map(([us]) => `- ${us}: Ralph cap hit — shipped as known gap`);
const knownGaps = gaps.length ? gaps.join("\n") : "none";

const debt = findings.filter((f) => f.status === "deferred");
const debtSection = debt.length
  ? ["| ID | Severity | File | Summary |", "|---|---|---|---|",
     ...debt.map((f) => `| ${f.id} | ${f.severity} | ${f.file ?? "—"} | ${f.summary.replaceAll("|", "\\|")} |`),
    ].join("\n")
  : "none";

const degradations = state.degraded
  ? `⚠ single-provider run (${state.degraded_reason ?? "codex unavailable"}) — cross-review: model-opposite fallback`
  : "none";

const docChanges = (state.docs_changed ?? []).length
  ? state.docs_changed.map((d) => `- ${d}`).join("\n")
  : "—";

const worktreeIsolation = state.worktree
  ? `dependencies: ${state.worktree.dependency_install ?? "unknown"}; ` +
    `.env.local: ${state.worktree.env_link_status ?? "unknown"}; ` +
    `database/auth infrastructure: shared; dev port: ${state.worktree.dev_port ?? "—"}`
  : "legacy run — no PROJ worktree metadata";

const worktreeCleanup = state.worktree
  ? `${state.worktree.cleanup_status ?? "pending"}` +
    (state.worktree.cleanup_reason ? ` — ${state.worktree.cleanup_reason}` : "")
  : "not applicable";

const values = {
  PROJ: state.proj,
  PROJ_NUMBER: projX,
  THEME: theme,
  BRANCH: state.branch ?? `proj/PROJ-${projX}`,
  BASE_SHA: state.base_sha ?? "—",
  SUMMARY: state.summary ?? "_no summary recorded in state.json_",
  STORIES: storiesBlock,
  GATE_SUMMARY: gateSummary,
  KNOWN_GAPS: knownGaps,
  DEBT_SECTION: debtSection,
  DEGRADATIONS: degradations,
  WORKTREE_ISOLATION: worktreeIsolation,
  WORKTREE_CLEANUP: worktreeCleanup,
  DOC_CHANGES: docChanges,
  RENDERED_AT: new Date().toISOString(),
};

let out = readFileSync(templatePath, "utf8");
for (const [k, v] of Object.entries(values)) out = out.replaceAll(`{{${k}}}`, String(v));

const left = out.match(/{{[A-Z_]+}}/g);
if (left) { console.error(`render-pr-body.mjs: unreplaced placeholders: ${[...new Set(left)].join(", ")}`); process.exit(1); }
process.stdout.write(out);
