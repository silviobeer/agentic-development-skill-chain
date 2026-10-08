#!/usr/bin/env node
// context-injector.mjs — provider context-injector adapter (CONCEPT.md §5).
//
// Injects the compiled canonical bundle into spawned agents, tier-gated by
// the role manifests. Spawn class decides FIRST, then agent type:
//   tier 0 (micro-fixer) and explore/scout -> inject NOTHING (the spawn
//   prompt already carries the finding/assignment verbatim);
//   tier 1/2 -> the role's canonical bundle, hash-verified against
//   bundles.lock.json (a stale or tampered bundle injects NOTHING plus a
//   stderr warning — wrong context is worse than no context).
//
// Carries NO minimalism ladder: Ponytail is the single source of the ladder
// on both providers — double injection is a bug.
//
// Usage:
//   node context-injector.mjs claude
//       Claude SubagentStart hook: reads the hook JSON on stdin, matches the
//       subagent type against the manifests' matchers, prints hook output
//       with additionalContext (or nothing).
//   node context-injector.mjs codex <role> [--path]
//       Codex prompt-file delivery: prints the codex projection content for
//       the role (--path: only the file path) — lane prompts reference it.
//
// PROJ resolution: $SKILLCHAIN_PROJ + $SKILLCHAIN_THEME if set, else the
// specs/PROJ-* dir with a context/bundles.lock.json whose state.json was
// updated most recently.
// Exit: 0 (also on inject-nothing) · 1 usage/infrastructure error
import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const sha256 = (s) => createHash("sha256").update(s).digest("hex");
const warn = (m) => console.error(`context-injector: ${m}`);

const mode = process.argv[2];
if (mode !== "claude" && mode !== "codex") {
  console.error("Usage: context-injector.mjs claude | codex <role> [--path]");
  process.exit(1);
}

// --- manifests (repo copy first, then skill tree) ------------------------------
function rolesDir() {
  if (existsSync("templates/roles")) return "templates/roles";
  return join(SCRIPT_DIR, "..", "manifests", "roles");
}
function frontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return {};
  const out = {};
  let listKey = null;
  for (const raw of m[1].split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    if (line.startsWith("- ")) { if (listKey) out[listKey].push(line.slice(2).trim()); continue; }
    const kv = line.match(/^([A-Za-z_][\w-]*):\s*(.*)$/);
    if (!kv) continue;
    if (raw.match(/^\s/) ) continue; // nested provider maps are irrelevant here
    const [, key, valRaw] = kv;
    if (valRaw === "") { out[key] = []; listKey = key; }
    else if (valRaw === "[]") { out[key] = []; listKey = null; }
    else { out[key] = valRaw.replace(/^["']|["']$/g, ""); listKey = null; }
  }
  return out;
}
function loadManifests() {
  const dir = rolesDir();
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => f.endsWith(".md")).sort()
    .map((f) => frontmatter(readFileSync(join(dir, f), "utf8")))
    .filter((m) => m.name && m.matcher);
}

// --- PROJ / bundle resolution ---------------------------------------------------
function contextDir() {
  const { SKILLCHAIN_PROJ, SKILLCHAIN_THEME } = process.env;
  if (SKILLCHAIN_PROJ && SKILLCHAIN_THEME) {
    return join("specs", `PROJ-${SKILLCHAIN_PROJ}-${SKILLCHAIN_THEME}`, "context");
  }
  if (!existsSync("specs")) return null;
  let best = null, bestTime = -1;
  for (const d of readdirSync("specs").filter((d) => d.startsWith("PROJ-"))) {
    const ctx = join("specs", d, "context");
    if (!existsSync(join(ctx, "bundles.lock.json"))) continue;
    const state = join("specs", d, "state.json");
    const t = existsSync(state) ? statSync(state).mtimeMs : statSync(ctx).mtimeMs;
    if (t > bestTime) { best = ctx; bestTime = t; }
  }
  return best;
}

function bundleFor(role, flavor /* "" | "claude" | "codex" */) {
  const ctx = contextDir();
  if (!ctx) { warn("no compiled context found (specs/PROJ-*/context/bundles.lock.json) — injecting nothing"); return null; }
  const lock = JSON.parse(readFileSync(join(ctx, "bundles.lock.json"), "utf8"));
  const rec = lock[role];
  if (!rec) { warn(`role '${role}' has no bundle in ${ctx} — injecting nothing`); return null; }
  const file = join(ctx, flavor ? `bundle-${role}.${flavor}.md` : `bundle-${role}.md`);
  if (!existsSync(file)) { warn(`${file} missing — injecting nothing`); return null; }
  const content = readFileSync(file, "utf8");
  const expected = flavor === "claude" ? rec.claude_hash : flavor === "codex" ? rec.codex_hash : rec.hash;
  if (sha256(content) !== expected) {
    warn(`${file} hash mismatch vs bundles.lock.json — STALE or tampered bundle, injecting nothing (recompile: node scripts/compile-context-bundles.mjs compile ...)`);
    return null;
  }
  return { file, content };
}

// --- claude: SubagentStart hook --------------------------------------------------
if (mode === "claude") {
  let input = "";
  try { input = readFileSync(0, "utf8"); } catch { /* no stdin */ }
  let agentType = "";
  try {
    const hook = JSON.parse(input || "{}");
    agentType = hook.agent_type ?? hook.subagent_type ?? hook.agentType ?? "";
  } catch { agentType = ""; }
  if (!agentType) process.exit(0); // unknown spawn — never guess-inject

  const manifests = loadManifests();
  // Exact name match wins (with optional skillchain- prefix), then matcher regex.
  const stripped = agentType.replace(/^skillchain-/i, "");
  let match = manifests.find((m) => m.name.toLowerCase() === stripped.toLowerCase());
  if (!match) {
    match = manifests.find((m) => {
      try { return new RegExp(m.matcher, "i").test(agentType); } catch { return false; }
    });
  }
  if (!match) process.exit(0);                      // not a framework role — inject nothing
  if ((match.inject ?? []).length === 0) process.exit(0); // tier 0 / explore — inject NOTHING by design

  const bundle = bundleFor(match.name, "");         // canonical body: same hash both providers
  if (!bundle) process.exit(0);
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: "SubagentStart",
      additionalContext: bundle.content,
    },
  }));
  process.exit(0);
}

// --- codex: prompt-file delivery ---------------------------------------------------
if (mode === "codex") {
  const role = process.argv[3];
  const pathOnly = process.argv.includes("--path");
  if (!role) { console.error("Usage: context-injector.mjs codex <role> [--path]"); process.exit(1); }
  const manifests = loadManifests();
  const m = manifests.find((x) => x.name === role);
  if (!m) { warn(`unknown role '${role}'`); process.exit(1); }
  if ((m.inject ?? []).length === 0) process.exit(0); // tier 0 / explore — nothing
  const bundle = bundleFor(role, "codex");
  if (!bundle) process.exit(1);
  process.stdout.write(pathOnly ? bundle.file + "\n" : bundle.content);
}
