#!/usr/bin/env node
// chain status — which step of the 0-to-8 chain each PROJ is on (done / current / pending / skipped).
// The single home of the chain-guide detection rules. Step level only: never progress inside a step.
// Read-only: reads specs/, docs/ and `git log`; never writes state.json, a ledger or any artifact.
//
// Usage: chain status [--short] [<X> | new]     run from the workspace root
//   --short  one line for the selected PROJ (empty outside a chain workspace)
//   <X>      PROJ number to show; default: the most advanced unfinished PROJ
//   new      the workspace before a PROJ is allocated (baseline, receiving marker), ignoring existing PROJs
// Exit: 0 ok · 2 no such PROJ · 64 usage
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const MARK = { done: "✅", current: "👉", pending: "⬜", skipped: "➖", optional: "🔹", blocked: "⛔" };
const LEGEND = "✅ done · 👉 current · ⬜ pending · ➖ skipped · 🔹 optional · ⛔ blocked";

// Chain order. main: counts toward Step N/M; skill: what to run when the step is current.
const STEPS = [
  { id: "0", main: true, label: "Baseline", name: "baseline" },
  { id: "1", main: true, label: "Concept", name: "concept", skill: "1_concept" },
  { id: "1a", label: "Clarification", name: "clarification", skill: "1a_clarification" },
  { id: "1b", label: "Visual companion", name: "visual-companion", skill: "1b_visual-companion" },
  { id: "1c", label: "Frontend design", name: "frontend-design", skill: "1c_frontend-design" },
  { id: "1d", label: "Prototyping", name: "prototyping", skill: "1d_prototyping" },
  { id: "1e", label: "Concept sync", name: "concept-sync", skill: "1e_concept-sync" },
  { id: "2", main: true, label: "Requirements", name: "requirements", list: "requirements-engineer", skill: "2_requirements-engineer" },
  { id: "2b", label: "Handoff package", name: "handoff-package", skill: "2b_handoff-package" },
  { id: "2c", label: "Review reconcile", name: "review-reconcile", skill: "2c_review-reconcile" },
  { id: "2e", label: "Handoff refinement", name: "handoff-refinement", skill: "2e_handoff-refinement" },
  { id: "3", main: true, label: "Architecture", name: "architecture", skill: "3_architecture" },
  { id: "4", main: true, label: "Plans", name: "writing-plans", skill: "4_writing-plans" },
  { id: "5", main: true, label: "Executing", name: "executing", skill: "5b_executing-large-model" },
  { id: "6", main: true, label: "QA", name: "qa", skill: "6_qa" },
  { id: "7", main: true, label: "Documentation", name: "documentation", skill: "7_documentation" },
  { id: "8", main: true, label: "Delivery", name: "delivery", skill: "8_delivery" },
];

// Pre-rename subfolder names (references/legacy-layout.md): current -> legacy twins.
const LEGACY = {
  "1b_visual-companion": ["2_visual-companion"], "1c_design": ["4_design"],
  "1d_prototypes": ["5_mockups", "1d_mockups"], "2_PRDs": ["3_PRDs"], "2b_handoff": ["8_handoff"],
  "3-4_plan": ["6_plan"], "5_progress": ["7_progress"],
};
// Signs of an existing codebase: a build manifest at the root or one folder down (monorepos),
// a conventional source folder, or source files at the root.
const CODE_MANIFESTS = ["package.json", "pyproject.toml", "setup.py", "requirements.txt", "go.mod", "Cargo.toml", "pom.xml", "build.gradle", "build.gradle.kts", "Gemfile", "composer.json", "Package.swift", "mix.exs", "deno.json", "CMakeLists.txt"];
const CODE_DIRS = ["src", "app", "lib", "apps", "packages", "services", "cmd", "internal"];
const CODE_FILE = /\.(py|go|rs|java|kt|swift|rb|php|cs|sln|csproj|fsproj|c|cc|cpp|h|ts|tsx|js|jsx|mjs|ex|exs|scala|dart)$/;
const NOT_CODE = new Set(["docs", "specs", "node_modules", "scripts", "templates"]);

const exists = p => fs.existsSync(p);
const read = p => { try { return fs.readFileSync(p, "utf8"); } catch { return ""; } };
const list = dir => { try { return fs.readdirSync(dir); } catch { return []; } };
const heading = (text, title) => new RegExp(`^#{1,6}\\s+${title}\\b`, "m").test(text);

function git(args) {
  try {
    return execFileSync("git", args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"], env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" } }).trim();
  } catch { return ""; }
}

const isDir = p => { try { return fs.statSync(p).isDirectory(); } catch { return false; } };

// The PROJ folders under specs/, plus flat legacy files (specs/PROJ-<X>-<theme>-spec.md|-plan.md, specs/concepts/).
// Anything else under specs/ (stray files, dangling links) is ignored. Two folders with the same number stay apart.
function findProjects() {
  const projects = [];
  const forNumber = (x, theme) => {
    const same = projects.filter(p => p.x === x);
    if (same.length === 1) return same[0];
    const p = { x, theme, dir: null, flat: [] };
    projects.push(p);
    return p;
  };
  const entries = list("specs").sort();
  for (const entry of entries) {
    const m = entry.match(/^PROJ-(\d+)-(.+)$/);
    if (m && isDir(path.join("specs", entry))) projects.push({ x: Number(m[1]), theme: m[2], dir: path.join("specs", entry), flat: [] });
  }
  for (const entry of entries) {
    const m = entry.match(/^PROJ-(\d+)-(.+?)-(spec|plan)\.md$/);
    if (m) forNumber(Number(m[1]), m[2]).flat.push(path.join("specs", entry));
  }
  for (const entry of list("specs/concepts").sort()) {
    const m = entry.match(/PROJ-(\d+)/);
    if (m && entry.endsWith(".md")) forNumber(Number(m[1]), entry.replace(/\.md$/, "").replace(/^.*?PROJ-\d+-?/, "") || "concept").flat.push(path.join("specs/concepts", entry));
  }
  const counts = projects.reduce((c, p) => c.set(p.x, (c.get(p.x) ?? 0) + 1), new Map());
  for (const p of projects) p.label = counts.get(p.x) > 1 ? `PROJ-${p.x}-${p.theme}` : `PROJ-${p.x}`;
  return projects.sort((a, b) => a.x - b.x || a.theme.localeCompare(b.theme));
}

function detect(p) {
  const X = p.x, legacy = new Set();
  const sub = name => {
    if (!p.dir) return null;
    const current = path.join(p.dir, name);
    if (exists(current)) return current;
    for (const old of LEGACY[name] ?? []) if (exists(path.join(p.dir, old))) { legacy.add(`${old} → ${name}`); return path.join(p.dir, old); }
    return current;
  };
  const files = (dir, re) => (dir ? list(dir).filter(n => re.test(n)).map(n => path.join(dir, n)) : []);
  const flatConcept = p.flat.find(f => f.startsWith("specs/concepts/"));
  const flatSpec = p.flat.find(f => f.endsWith("-spec.md"));
  const flatPlan = p.flat.find(f => f.endsWith("-plan.md"));
  if (p.flat.length) legacy.add("flat specs/ files");

  const conceptFile = p.dir && exists(path.join(p.dir, "1_concept", `PROJ-${X}-concept.md`)) ? path.join(p.dir, "1_concept", `PROJ-${X}-concept.md`) : flatConcept;
  const concept = conceptFile ? read(conceptFile) : "";
  const vc = sub("1b_visual-companion"), design = sub("1c_design"), proto = sub("1d_prototypes");
  const prdDir = sub("2_PRDs"), handoff = sub("2b_handoff"), plan = sub("3-4_plan"), progressDir = sub("5_progress");
  const layout = vc ? read(path.join(vc, "layout-decision.md")) : "";
  const carried = heading(layout, "Carried Forward");
  const prds = files(prdDir, new RegExp(`^PROJ-${X}-PRD-.*\\.md$`)).filter(f => !/-review-decisions\.md$/.test(f));
  if (flatSpec) prds.push(flatSpec);
  const plans = files(plan, new RegExp(`^PROJ-${X}-wave-.*-plan\\.md$`));
  const waves = new Set(plans.map(f => path.basename(f).match(/-wave-(\d+)-plan\.md$/)?.[1]).filter(Boolean));
  const iterations = proto ? read(path.join(proto, "iteration-log.md")) : "";
  const synced = heading(concept, "Concept Sync Log");
  // Concept drift: an iteration that affects the concept, later than every iteration a sync entry names.
  const affecting = [];
  let iteration = 1;
  for (const line of iterations.split("\n")) {
    const m = line.match(/^#{2,}\s+Iteration\s+(\d+)/);
    if (m) iteration = Number(m[1]);
    else if (/^\s*-\s*Affects concept:\s*yes/i.test(line)) affecting.push(iteration);
  }
  const syncLog = concept.split(/^#{1,6}\s+Concept Sync Log\b.*$/m)[1]?.split(/^#{1,6}\s/m)[0] ?? "";
  // Four-digit numbers are dates, not iterations ("iteration 3, 2026-11-01").
  const named = [...syncLog.matchAll(/iterations?\s+([\d\s,&–-]+(?:and\s+\d+)?)/gi)].flatMap(m => m[1].match(/\d+/g) ?? []).map(Number).filter(n => n < 1000);
  const syncedThrough = !synced ? 0 : named.length ? Math.max(...named) : Infinity;
  const drift = affecting.some(n => n > syncedThrough);
  const briefs = list("specs/_clarification").filter(n => /-stakeholder_brief(-r\d+)?\.md$/.test(n));
  const progress = progressDir ? read(path.join(progressDir, `PROJ-${X}-progress.md`)) : "";
  // A gate re-run appends a second PASSED block for the same wave: count waves, not blocks.
  const passed = new Set([...progress.matchAll(/Wave (\d+) Gate — PASSED/g)].map(m => m[1]));
  const projectDoc = read("docs/PROJECT.md");
  // The receiving path: an external handoff marker in the PROJ, or a PROJ without a concept in a
  // coordination repo (delivery-workspace.json). It never routes to product-vision or intake.
  const receiving = p.dir ? exists(path.join(p.dir, "external-handoff.json")) || (exists("delivery-workspace.json") && !conceptFile) : false;
  // handoff-refinement writes external-handoff.json before its review; it is done only when the project
  // README marks the current run ready for architecture.
  const refinementReady = p.dir ? /^Current run:.*\(status:\s*ready for architecture\)/m.test(read(path.join(p.dir, "README.md"))) : false;

  let state = null;
  if (p.dir && exists(path.join(p.dir, "state.json"))) {
    try { state = JSON.parse(read(path.join(p.dir, "state.json"))); } catch { state = null; }
    if (!state || typeof state !== "object") state = { phase: "?", status: "unreadable" };
  }
  const docsCommitted = () => {
    if (!new RegExp(`PROJ-${X}(?!\\d)`).test(projectDoc)) return false;
    const latest = git(["log", "-1", "--topo-order", "--format=%s", "-E",
      `--grep=^docs\\(PROJ-${X}\\): Update project documentation`, `--grep=^feat\\(PROJ-${X}-PRD-[^)]*\\)`, `--grep=^test\\(PROJ-${X}\\)`]);
    return latest.startsWith(`docs(PROJ-${X})`);
  };

  // done: artifact evidence (chain-guide rules 1-10). needed: an optional step the rules require now.
  const done = {
    1: Boolean(conceptFile), "1a": briefs.some(b => concept.includes(b)),
    "1b": Boolean(vc) && exists(path.join(vc, "layout-decision.md")) && exists(path.join(vc, "layout-exploration.html")),
    "1c": Boolean(design) && exists(path.join(design, "design-language.md")),
    "1d": Boolean(proto) && !carried && exists(path.join(proto, "sitemap.html")) && exists(path.join(proto, "implementation-handoff.md")),
    "1e": synced && !drift, 2: prds.length > 0,
    "2b": files(handoff, /./).some(d => exists(path.join(d, "README.md"))),
    "2c": files(prdDir, /(-review-decisions|^review-changelog)\.md$/).length > 0,
    "2e": receiving && refinementReady,
    3: (plan && exists(path.join(plan, `PROJ-${X}-architecture.md`))) || false,
    4: plans.length > 0 || Boolean(flatPlan),
    5: waves.size > 0 && [...waves].every(n => passed.has(n)),
    6: prds.some(f => heading(read(f), "QA Test Results")),
    7: false, 8: false,
  };
  done[7] = done[6] && docsCommitted();
  const needed = {
    "1d": carried || done["1b"],
    // Before Checkpoint 1 only: once a run has started, an old drift is no longer this chain's step.
    "1e": !state && (drift || (heading(concept, "Candidate Directions") && heading(layout, "Selected Direction"))),
  };
  // Still owed after a later step is done: only concept drift (the PRDs may need the sync too).
  const owed = { "1e": !state && drift };

  // After Checkpoint 1, state.json decides steps 5-8 (and implies 1-4 were done).
  let phaseStep = null, blocked = false, awaitingMerge = false;
  if (state) {
    const order = { CP1: 5, P0: 5, P5: 5, P6: 6, P7: 7, P8: 8, done: 9 };
    phaseStep = order[state.phase] ?? 5;
    if (state.status === "done" && ["P5", "P6", "P7"].includes(state.phase)) phaseStep += 1;
    if (state.phase === "P8" && state.status === "done") awaitingMerge = true;
    blocked = state.status === "blocked";
    for (const id of ["3", "4"]) done[id] = true;
    for (const id of ["5", "6", "7", "8"]) done[id] = Number(id) < phaseStep;
    if (!receiving) { done[1] = true; done[2] = true; }
  }

  const track = receiving ? "receiving" : /Delivery track\W*discovery/i.test(concept) ? "discovery" : "full";
  const steps = STEPS.filter(s => track === "discovery" ? !["3", "4", "5", "6", "7", "8"].includes(s.id) : true)
    .filter(s => s.id !== "2e" || receiving)
    .map(s => ({ ...s, done: s.id === "0" ? exists("docs/PRODUCT.md") : Boolean(done[s.id]) }));
  for (const s of steps) {
    // The receiving path (2e) replaces the product-side steps.
    if (receiving && ["1", "1a", "1b", "1c", "1d", "1e", "2", "2b", "2c"].includes(s.id)) s.notApplicable = true;
    if (s.id === "2e") s.main = true;
    // Interactive runs (no state.json) end at documentation; delivery needs the framework run.
    if (s.id === "8" && !state) s.frameworkOnly = true;
  }
  // The baseline comes before any other step on the full chain (P0 needs it). A discovery feature in an
  // existing product starts at concept instead, and the receiving path (2e) owns its baselines. Once a
  // framework run exists, state.json decides the step; a missing baseline is only noted.
  if (!steps[0].done && track !== "full") steps[0].notApplicable = true;

  // The current step is the first main step after the last done one, or a required optional
  // step in between. A step not done before the last done step was skipped, unless the rules
  // still require it (concept drift found after the PRDs): then it stays pending. Optional
  // steps after the last done step stay optional.
  const lastDone = steps.reduce((last, s, i) => (s.done && !s.notApplicable ? i : last), -1);
  let current = steps[0].done || steps[0].notApplicable || state ? steps.findIndex((s, i) => i > lastDone && !s.done && !s.notApplicable && (s.main || needed[s.id])) : 0;
  if (current >= 0 && steps[current].frameworkOnly) current = -1;
  for (const [i, s] of steps.entries()) {
    if (s.done) s.status = "done";
    else if (i === current) s.status = blocked ? "blocked" : "current";
    else if (s.notApplicable || (i < lastDone && !owed[s.id])) s.status = "skipped";
    else if (s.main) s.status = current < 0 ? "skipped" : "pending";
    else s.status = needed[s.id] || owed[s.id] ? "pending" : "optional";
  }
  const next = current >= 0 ? steps.slice(current + 1).find(s => s.status === "pending") : null;
  const total = track === "discovery" ? 2 : 8;
  return { p, X, state, track, steps, current: current >= 0 ? steps[current] : null, next, blocked, awaitingMerge, total, legacy: [...legacy], progressDir };
}

function stepNumber(s, total) { return `Step ${s.id}/${total} ${s.label}`; }

function shortLine(r) {
  const who = r.p.label;
  if (!r.current) {
    if (r.track === "discovery") return `${who} · ✅ Discovery complete (${r.total}/${r.total})`;
    if (r.state?.phase === "done") return `${who} · ✅ Chain complete (8/8)`;
    return `${who} · ✅ Complete (interactive run) · ready for release`;
  }
  const label = r.current.id === "0" ? `Step 0/${r.total} Baseline (${baselineNext()})` : stepNumber(r.current, r.total);
  const head = `${who} · ${r.blocked ? MARK.blocked : MARK.current} ${label}`;
  if (r.blocked) return `${head} · blocked: ${path.join(r.progressDir ?? "", "stop-report.md")}`;
  if (r.awaitingMerge) return `${head} · next: review and merge the PR (Checkpoint 2)`;
  return r.next ? `${head} · next: ${r.next.name}` : head;
}

function hasCode() {
  if (CODE_MANIFESTS.some(exists) || CODE_DIRS.some(isDir)) return true;
  const top = list(".");
  if (top.some(n => CODE_FILE.test(n))) return true;
  return top.filter(n => !n.startsWith(".") && !NOT_CODE.has(n) && isDir(n)).some(d => CODE_MANIFESTS.some(m => exists(path.join(d, m))));
}
// The baseline skill still to run: intake (0b) for an existing codebase, else product-vision (0a), then bootstrap (0c).
function baselineNext() {
  if (!exists("docs/PRODUCT.md")) return hasCode() ? "intake" : "product-vision";
  return "bootstrap";
}
const BASELINE_SKILL = { intake: "0b_intake", "product-vision": "0a_product-vision", bootstrap: "0c_bootstrap" };

function checklist(r) {
  const out = [];
  const head = [`PROJ-${r.X}-${r.p.theme}`, `track: ${{ full: "full chain", discovery: "discovery (Linear handoff)", receiving: "external handoff (receiving)" }[r.track]}`];
  if (r.state) head.push(r.state.status === "unreadable" ? "state.json unreadable" : `state: ${r.state.phase}:${r.state.status}`);
  if (r.legacy.length) head.push(`legacy layout: ${r.legacy.join(", ")}`);
  out.push(head.join(" · "));
  for (const s of r.steps) {
    let note = "";
    if (s.id === "0" && !s.done) note = s.status === "skipped" ? "docs/PRODUCT.md missing" : `run ${baselineNext()}`;
    if (s.id === "0" && s.bootstrapNote) note = s.bootstrapNote;
    if (s.frameworkOnly && s.status === "skipped") note = "framework runs only";
    out.push(`${MARK[s.status]} ${s.id.padEnd(3)} ${(s.list ?? s.name).padEnd(22)}${note ? ` ${note}` : ""}`.trimEnd());
  }
  if (r.blocked) out.push(`Blocked: read ${path.join(r.progressDir ?? "", "stop-report.md")}`);
  else if (r.current) out.push(`Next skill: ${r.current.id === "0" ? BASELINE_SKILL[baselineNext()] : r.current.skill}`);
  return out;
}

// The workspace before a PROJ exists: the baseline path, or the receiving path when a
// delivery-workspace.json coordination marker is present (it never routes to product-vision or intake).
function noProjectSteps() {
  const receiving = exists("delivery-workspace.json");
  const baselineDone = exists("docs/PRODUCT.md") && hasCode();
  const steps = STEPS.filter(s => (receiving ? !["1", "1a", "1b", "1c", "1d", "1e", "2", "2b", "2c"].includes(s.id) : s.id !== "2e"))
    .map(s => ({ ...s, main: s.main || s.id === "2e" }));
  const currentId = receiving ? "2e" : baselineDone ? "1" : "0";
  for (const s of steps) {
    if (s.id === "0" && (baselineDone || receiving)) s.status = baselineDone ? "done" : "skipped";
    else if (s.id === currentId) s.status = "current";
    else s.status = s.main ? "pending" : "optional";
  }
  const zero = steps[0];
  if (receiving && !baselineDone) zero.bootstrapNote = "per code repo, owned by handoff-refinement";
  if (currentId === "0" && exists("docs/PRODUCT.md")) zero.bootstrapNote = "run bootstrap (0c); skip it on the discovery track";
  const current = steps.find(s => s.id === currentId);
  const next = steps.slice(steps.indexOf(current) + 1).find(s => s.status === "pending");
  return { steps, current, next, track: receiving ? "receiving" : "full" };
}

function main() {
  const args = process.argv.slice(2);
  let short = false, wanted = null;
  for (const arg of args) {
    if (arg === "--short") short = true;
    else if ((/^\d+$/.test(arg) || arg === "new") && wanted === null) wanted = arg === "new" ? arg : Number(arg);
    else { console.error("Usage: chain status [--short] [<X> | new]"); process.exit(64); }
  }
  if (!exists("specs") && !exists("docs/PRODUCT.md") && !exists("delivery-workspace.json")) {
    if (!short) console.log("Not a chain workspace (no specs/, docs/PRODUCT.md or delivery-workspace.json here).");
    return;
  }
  const projects = findProjects();
  if (typeof wanted === "number" && !projects.some(p => p.x === wanted)) { console.error(`chain status: no PROJ-${wanted} under specs/`); process.exit(2); }

  if (!projects.length || wanted === "new") {
    const r = noProjectSteps();
    const who = projects.length ? "New PROJ" : "No PROJ yet";
    const label = r.current.id === "0" ? `Baseline (${baselineNext()})` : r.current.label;
    const line = `${who} · ${MARK.current} Step ${r.current.id}/8 ${label}${r.next ? ` · next: ${r.next.name}` : ""}`;
    if (short) { console.log(line); return; }
    console.log(`${who} · track: ${r.track === "receiving" ? "external handoff (receiving)" : "full chain"}`);
    for (const s of r.steps) console.log(`${MARK[s.status]} ${s.id.padEnd(3)} ${(s.list ?? s.name).padEnd(22)}${s.bootstrapNote ? ` ${s.bootstrapNote}` : ""}`.trimEnd());
    console.log(`Next skill: ${r.current.id === "0" ? BASELINE_SKILL[baselineNext()] : r.current.skill}`);
    console.log(LEGEND);
    return;
  }

  const results = projects.map(detect);
  // Finish what's started: the unfinished PROJ furthest along, ties to the newest.
  const rank = r => (r.current ? STEPS.findIndex(s => s.id === r.current.id) : -1);
  const candidates = wanted !== null ? results.filter(r => r.X === wanted) : results;
  const pick = [...candidates].sort((a, b) => rank(b) - rank(a) || b.X - a.X)[0];
  if (short) {
    const others = results.filter(r => r !== pick && r.current).length;
    console.log(shortLine(pick) + (others && wanted === null ? ` (+${others} open PROJ${others > 1 ? "s" : ""})` : ""));
    return;
  }
  if (results.length > 1) { for (const r of results) console.log(shortLine(r)); console.log(""); }
  for (const line of checklist(pick)) console.log(line);
  console.log(LEGEND);
}

main();
