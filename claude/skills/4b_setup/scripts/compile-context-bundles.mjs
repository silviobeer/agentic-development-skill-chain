#!/usr/bin/env node
// compile-context-bundles.mjs — the context compiler (CONCEPT.md §5, §7).
//
// Compiles ONE canonical context bundle per role (from the provider-neutral
// role manifests) plus thin Claude/Codex projections that embed the canonical
// body VERBATIM — both providers receive the same canonical bundle hash.
// Counts tokens against the per-role budget. A breach blocks only that role:
// fitting bundles are written and blocked-roles.json records the denial.
//
// The source-id -> path map and the hard never-inject list (whole PRDs,
// other stories' wave plans, progress.md, SKILL.md texts, src/**/agent.md)
// live HERE, not in the manifests: a manifest can only pick from the closed
// vocabulary below. agent.md files are distributed via the reading protocol,
// never injected.
//
// Output is DETERMINISTIC (no timestamps inside bundle files) so two compiles
// of the same inputs are byte-identical; only bundles.lock.json carries
// compiled_at. All writes are atomic (tmp + rename). The compiler is
// state-free — recording hashes into state.json is the caller's job
// (4b_setup step 6a, via state.sh).
//
// Usage:
//   node compile-context-bundles.mjs compile <proj-x> <theme> [--wave N] [--budget N] [--roles-dir D]
//   node compile-context-bundles.mjs verify  <proj-x> <theme> [--roles-dir D]
//   node compile-context-bundles.mjs show    <proj-x> <theme> <role>
//
// Env: CONTEXT_BUNDLE_BUDGET  overrides every manifest budget (tokens)
// Exit: 0 ok · 1 projection drift / verify mismatch / bad manifest · 2 missing inputs · 64 usage
import { readFileSync, writeFileSync, existsSync, readdirSync, renameSync, mkdirSync, rmSync } from "node:fs";
import { join, dirname } from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));

function usage() {
  console.error(
    "Usage: compile-context-bundles.mjs <compile|verify|show> <proj-x> <theme> [args]\n" +
    "  compile [--wave N] [--budget N] [--roles-dir D]\n" +
    "  verify  [--roles-dir D]\n" +
    "  show    <role>",
  );
  process.exit(64);
}

const [cmd, projX, theme, ...rest] = process.argv.slice(2);
if (!cmd || !projX || !theme) usage();

let wave = null, budgetOverride = null, rolesDirArg = null, showRole = null;
for (let i = 0; i < rest.length; i++) {
  if (rest[i] === "--wave") wave = parseInt(rest[++i], 10);
  else if (rest[i] === "--budget") budgetOverride = parseInt(rest[++i], 10);
  else if (rest[i] === "--roles-dir") rolesDirArg = rest[++i];
  else if (cmd === "show" && !showRole) showRole = rest[i];
  else usage();
}
if (process.env.CONTEXT_BUNDLE_BUDGET) budgetOverride = parseInt(process.env.CONTEXT_BUNDLE_BUDGET, 10);

const BASE = `specs/PROJ-${projX}-${theme}`;
const OUT_DIR = join(BASE, "context");
const LOCK = join(OUT_DIR, "bundles.lock.json");
const BLOCKED = join(OUT_DIR, "blocked-roles.json");

function fail(msg, code = 1) { console.error(`compile-context-bundles: ${msg}`); process.exit(code); }
function sha256(s) { return createHash("sha256").update(s).digest("hex"); }
function tokens(s) { return Math.ceil(s.length / 4); } // documented heuristic: ~4 chars/token

// --- role manifests -----------------------------------------------------------
function rolesDir() {
  if (rolesDirArg) return rolesDirArg;
  if (existsSync("templates/roles")) return "templates/roles";           // repo copy (4b_setup installs)
  return join(SCRIPT_DIR, "..", "manifests", "roles");                    // skill tree
}

// Minimal YAML subset for the manifest frontmatter: flat `key: value`,
// string lists (`- item`), one-level nested maps under `claude:`/`codex:`.
function parseFrontmatter(text, file) {
  const m = text.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!m) fail(`${file}: missing frontmatter`);
  const [, fm, body] = m;
  const out = {};
  let currentKey = null, currentMap = null;
  for (const raw of fm.split("\n")) {
    if (!raw.trim() || raw.trim().startsWith("#")) continue;
    const indent = raw.match(/^\s*/)[0].length;
    const line = raw.trim();
    if (line.startsWith("- ")) {
      if (!currentKey || !Array.isArray(out[currentKey])) fail(`${file}: stray list item '${line}'`);
      out[currentKey].push(coerce(line.slice(2).trim()));
      continue;
    }
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (!kv) fail(`${file}: unparseable line '${line}'`);
    const [, key, valRaw] = kv;
    if (indent > 0 && currentMap) { currentMap[key] = coerce(valRaw); continue; }
    currentMap = null;
    if (valRaw === "") {
      // either a list (items follow) or a nested map (indented lines follow)
      if (key === "claude" || key === "codex") { out[key] = {}; currentMap = out[key]; currentKey = null; }
      else { out[key] = []; currentKey = key; }
    } else if (valRaw === "[]") {
      out[key] = []; currentKey = null;
    } else {
      out[key] = coerce(valRaw); currentKey = null;
    }
  }
  return { fm: out, body: body.trim() };
}
function coerce(v) {
  v = v.replace(/\s+#.*$/, "").trim();
  if (/^".*"$/.test(v) || /^'.*'$/.test(v)) return v.slice(1, -1);
  if (v === "true") return true;
  if (v === "false") return false;
  if (/^-?\d+$/.test(v)) return parseInt(v, 10);
  return v;
}

const SOURCE_IDS = [
  "product", "architecture-overview", "architecture-delta", "guidelines",
  "ground-file", "test-conventions", "design-system", "components",
  "api-contracts-own-wave", "security-baseline", "review-criteria", "diff-scope",
];

function loadManifests() {
  const dir = rolesDir();
  if (!existsSync(dir)) fail(`roles dir not found: ${dir}`, 2);
  const manifests = [];
  for (const f of readdirSync(dir).filter((f) => f.endsWith(".md")).sort()) {
    const { fm, body } = parseFrontmatter(readFileSync(join(dir, f), "utf8"), join(dir, f));
    for (const req of ["name", "description", "tier", "scope", "inject", "budget_tokens", "matcher"])
      if (fm[req] === undefined) fail(`${f}: missing required manifest field '${req}'`);
    for (const id of fm.inject)
      if (!SOURCE_IDS.includes(id)) fail(`${f}: unknown inject source id '${id}' (closed vocabulary: ${SOURCE_IDS.join(", ")})`);
    manifests.push({ ...fm, preamble: body, file: f });
  }
  if (manifests.length === 0) fail(`no role manifests in ${rolesDir()}`, 2);
  return manifests;
}

// --- sources ------------------------------------------------------------------
function readOr(path, note) {
  if (existsSync(path)) return readFileSync(path, "utf8").trim();
  return `_(source missing: ${path} — ${note})_`;
}

function apiContractsOwnWave() {
  const path = join(BASE, "api-contracts.md");
  if (!existsSync(path)) return `_(source missing: ${path} — no contracts yet)_`;
  const full = readFileSync(path, "utf8");
  if (wave === null) {
    return `_(compiled without wave scope — recompile with --wave N at wave start for own-wave contracts)_`;
  }
  // Keep ## sections whose heading names this wave; heuristic, documented.
  const sections = full.split(/^(?=## )/m);
  const kept = sections.filter((s) => new RegExp(`wave\\s*${wave}\\b`, "i").test(s.split("\n")[0]));
  if (kept.length === 0) return `_(no api-contracts sections matched wave ${wave} — check specs/${"PROJ-" + projX}-${theme}/api-contracts.md headings)_`;
  return kept.join("").trim();
}

function sourceContent(id) {
  switch (id) {
    case "product":              return { title: "Product (docs/PRODUCT.md)", text: readOr("docs/PRODUCT.md", "no intake baseline yet") };
    case "architecture-overview":return { title: "Architecture overview (docs/ARCHITECTURE.md)", text: readOr("docs/ARCHITECTURE.md", "no intake baseline yet") };
    case "architecture-delta": {
      // Until Stage 3 introduces the baseline/delta rework, the architecture
      // skill writes 3-4_plan/PROJ-<X>-architecture.md — fall back to it so the
      // bundle carries the PROJ's actual architecture decisions.
      const delta = join(BASE, "architecture-delta.md");
      if (existsSync(delta)) return { title: `Architecture delta of this PROJ (${delta})`, text: readFileSync(delta, "utf8").trim() };
      const arch = join(BASE, "3-4_plan", `PROJ-${projX}-architecture.md`);
      if (existsSync(arch)) return { title: `PROJ architecture (${arch} — architecture-delta.md ships with Stage 3)`, text: readFileSync(arch, "utf8").trim() };
      return { title: `Architecture delta of this PROJ (${delta})`, text: `_(source missing: ${delta} and ${arch} — no new decisions recorded)_` };
    }
    case "guidelines":           return { title: "Guidelines (docs/GUIDELINES.md)", text: readOr("docs/GUIDELINES.md", "no intake baseline yet") };
    case "ground-file":          return { title: `Validated assumptions (${BASE}/ground-file.md)`, text: readOr(join(BASE, "ground-file.md"), "generated in P0 step 6b") };
    case "test-conventions":     return { title: "Test conventions (docs/test-conventions.md)", text: readOr("docs/test-conventions.md", "no intake baseline yet") };
    case "design-system":        return { title: "Design system (docs/DESIGN-SYSTEM.md)", text: readOr("docs/DESIGN-SYSTEM.md", "no intake baseline yet") };
    case "components":           return { title: "Component registry (docs/components.md)", text: "Read `docs/components.md` before creating or changing a component; it is deliberately referenced by path so its inventory does not consume this bundle's budget." };
    case "security-baseline":    return { title: "Security baseline (docs/security-baseline.md)", text: readOr("docs/security-baseline.md", "no intake baseline yet") };
    case "api-contracts-own-wave": return { title: "API contracts — own wave only", text: apiContractsOwnWave() };
    case "review-criteria":      return { title: "Review criteria", text: "_(dynamic: your persona's review criteria arrive in the spawn prompt — read them there)_" };
    case "diff-scope":           return { title: "Diff scope", text: "_(dynamic: the diff scope for this review arrives in the spawn prompt)_" };
    default: fail(`unknown source id '${id}'`);
  }
}

// --- bundle assembly ------------------------------------------------------------
function canonicalBody(manifest) {
  const parts = [
    `# Context bundle — role: ${manifest.name} (tier ${manifest.tier}, scope ${manifest.scope})`,
    "",
    manifest.preamble,
    "",
    "_Never injected by design: whole PRDs, other stories' wave plans, progress.md,",
    "SKILL.md texts, src/**/agent.md (reading protocol only — read the folder's",
    "agent.md before your first edit there)._",
  ];
  for (const id of manifest.inject) {
    const { title, text } = sourceContent(id);
    parts.push("", `## ${title}`, "", text);
  }
  return parts.join("\n").trim() + "\n";
}

function claudeProjection(manifest, body) {
  return `<!-- skillchain claude projection · role: ${manifest.name} · injected by the SubagentStart hook (context-injector.mjs claude) · canonical body below, verbatim -->\n${body}`;
}
function codexProjection(manifest, body) {
  return `<!-- skillchain codex projection · role: ${manifest.name} · prompt-file delivery: a codex lane reads this file before implementing · canonical body below, verbatim -->\n${body}`;
}

function agentFileContent(manifest) {
  const model = manifest.claude?.model ? `model: ${manifest.claude.model}\n` : "";
  return `---\nname: skillchain-${manifest.name}\ndescription: "${manifest.description.replace(/"/g, '\\"')}"\ntools: ${manifest.claude?.tools ?? "Read,Grep,Glob"}\n${model}---\n\n${manifest.preamble}\n\nYour context bundle (role: ${manifest.name}) is injected automatically via the\nSubagentStart hook — nobody pastes bundles into spawn prompts. If the bundle\nis absent, say so instead of improvising conventions.\n`;
}

function atomicWrite(path, content) {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.tmp-${process.pid}`;
  writeFileSync(tmp, content);
  renameSync(tmp, path);
}

function compileAll() {
  const manifests = loadManifests();
  const compiled = [];   // { manifest, body, claude, codex, tokens }
  const breaches = [];
  for (const m of manifests) {
    if (m.inject.length === 0) continue;   // tier 0 / explore: no bundle, injector emits nothing
    const body = canonicalBody(m);
    const t = tokens(body);
    const budget = budgetOverride ?? m.budget_tokens;
    if (t > budget) { breaches.push({ role: m.name, tokens: t, budget }); continue; }
    const cl = claudeProjection(m, body);
    const cx = codexProjection(m, body);
    // Projection drift check: the canonical body must be embedded verbatim.
    const embedded = (p) => p.slice(p.indexOf("\n") + 1);
    if (sha256(embedded(cl)) !== sha256(body) || sha256(embedded(cx)) !== sha256(body))
      fail(`${m.name}: projection drift — a provider projection does not embed the canonical body verbatim`);
    compiled.push({ manifest: m, body, cl, cx, tokens: t });
  }
  return { compiled, breaches };
}

function removeRoleBundles(role) {
  for (const suffix of [".md", ".claude.md", ".codex.md"])
    rmSync(join(OUT_DIR, `bundle-${role}${suffix}`), { force: true });
}

if (cmd === "compile") {
  if (!existsSync(BASE)) fail(`${BASE} not found — run from the repo root of an active PROJ`, 2);
  const { compiled, breaches } = compileAll();
  const lock = {};
  for (const { manifest: m, body, cl, cx, tokens: t } of compiled) {
    atomicWrite(join(OUT_DIR, `bundle-${m.name}.md`), body);
    atomicWrite(join(OUT_DIR, `bundle-${m.name}.claude.md`), cl);
    atomicWrite(join(OUT_DIR, `bundle-${m.name}.codex.md`), cx);
    lock[m.name] = {
      hash: sha256(body),
      claude_hash: sha256(cl),
      codex_hash: sha256(cx),
      tokens: t,
      wave: wave,
      compiled_at: new Date().toISOString(),
    };
  }
  atomicWrite(LOCK, JSON.stringify(lock, null, 2) + "\n");
  atomicWrite(BLOCKED, JSON.stringify(breaches, null, 2) + "\n");
  for (const { role } of breaches) removeRoleBundles(role);
  for (const [role, rec] of Object.entries(lock))
    console.log(`compiled ${role}: ${rec.tokens} tokens · ${rec.hash.slice(0, 12)}… · wave ${rec.wave ?? "-"}`);
  console.log(`✓ ${Object.keys(lock).length} bundle(s) -> ${OUT_DIR} (canonical + claude/codex projections, one hash)`);
  if (breaches.length > 0) {
    console.warn(`⚠ blocked role(s), no bundle written: ${breaches.map((b) => `${b.role} (${b.tokens}/${b.budget})`).join(", ")}`);
    console.warn("  Spawn only roles with a compiled bundle; condense their sources or raise that role's manifest budget when its scope genuinely requires it.");
  }
  // Claude agent-file projection. Safety: ONLY skillchain-<role>.md files are
  // ever written — pre-existing agents in .claude/agents/ are never touched.
  let agentFiles = 0;
  for (const m of loadManifests()) {
    if (m.claude?.agent_file === true) {
      atomicWrite(join(".claude", "agents", `skillchain-${m.name}.md`), agentFileContent(m));
      agentFiles++;
    }
  }
  console.log(`✓ ${agentFiles} agent file(s) projected -> .claude/agents/skillchain-*.md`);
} else if (cmd === "verify") {
  if (!existsSync(LOCK)) fail(`${LOCK} missing — nothing to verify (run compile first)`, 2);
  const lock = JSON.parse(readFileSync(LOCK, "utf8"));
  const wavesSeen = [...new Set(Object.values(lock).map((r) => r.wave))];
  if (wavesSeen.length > 1) fail(`lock file mixes wave scopes (${wavesSeen.join(", ")}) — recompile`);
  wave = wavesSeen[0] ?? null;
  const { compiled, breaches } = compileAll();
  const problems = [];
  for (const { manifest: m, body, tokens: t } of compiled) {
    const rec = lock[m.name];
    if (!rec) { problems.push(`${m.name}: in manifests but not in lock — recompile`); continue; }
    if (rec.hash !== sha256(body)) problems.push(`${m.name}: semantic drift — docs/manifests changed since compile (lock ${rec.hash.slice(0, 12)}…, now ${sha256(body).slice(0, 12)}…)`);
    const onDisk = join(OUT_DIR, `bundle-${m.name}.md`);
    if (!existsSync(onDisk)) problems.push(`${m.name}: bundle file missing on disk`);
    else if (sha256(readFileSync(onDisk, "utf8")) !== rec.hash) problems.push(`${m.name}: bundle file on disk was tampered with (hash != lock)`);
    for (const [proj, key] of [["claude", "claude_hash"], ["codex", "codex_hash"]]) {
      const p = join(OUT_DIR, `bundle-${m.name}.${proj}.md`);
      if (!existsSync(p)) problems.push(`${m.name}: ${proj} projection missing`);
      else if (sha256(readFileSync(p, "utf8")) !== rec[key]) problems.push(`${m.name}: ${proj} projection drift (hash != lock)`);
    }
    const budget = budgetOverride ?? m.budget_tokens;
    if (t > budget) problems.push(`${m.name}: ${t} tokens > budget ${budget}`);
  }
  for (const role of Object.keys(lock))
    if (!compiled.find((c) => c.manifest.name === role)) problems.push(`${role}: in lock but no longer compiled from manifests`);
  const blocked = existsSync(BLOCKED) ? JSON.parse(readFileSync(BLOCKED, "utf8")) : [];
  if (JSON.stringify(blocked) !== JSON.stringify(breaches)) problems.push("blocked roles changed — recompile");
  if (problems.length > 0) fail(`verify FAILED:\n  ${problems.join("\n  ")}`);
  console.log(`✓ verify ok — ${Object.keys(lock).length} bundle(s) match the lock, budgets hold`);
} else if (cmd === "show") {
  if (!showRole) usage();
  const p = join(OUT_DIR, `bundle-${showRole}.md`);
  if (!existsSync(p)) fail(`${p} not found (tier-0/explore roles have no bundle by design)`, 2);
  process.stdout.write(readFileSync(p, "utf8"));
} else {
  usage();
}
