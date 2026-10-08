#!/usr/bin/env node
// Synchronize the P0 helper inventory; never overwrite an unreviewed local edit.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";

const inventory = [
  ...["state.sh", "preflight.sh", "env-local.sh", "ponytail-check.sh", "compile-context-bundles.mjs", "context-injector.mjs", "worktree.sh", "validate-wave-plan.mjs", "migration-drift-check.sh", "story-slice.mjs", "sync-framework.mjs"].map(name => [`5_executing/scripts/${name}`, `scripts/${name}`]),
  ...["backend-implementer", "explore", "frontend-implementer", "implementer", "micro-fixer", "reviewer"].map(name => [`5_executing/manifests/roles/${name}.md`, `templates/roles/${name}.md`]),
  ["5_executing/templates/decisions.md.tmpl", "templates/decisions.md.tmpl"],
  ...["cross-review.sh", "review-with-claude.sh", "review-with-codex.sh"].map(name => [`cross-review/scripts/${name}`, `scripts/${name}`]),
  ["cross-review/templates/cross-review-prompt.md.tmpl", "templates/cross-review-prompt.md.tmpl"],
  ...["ledger.mjs", "harvest-debt.sh"].map(name => [`6_qa/scripts/${name}`, `scripts/${name}`]),
  ["7_documentation/scripts/curation-caps.sh", "scripts/curation-caps.sh"],
  ["0b_intake/scripts/intake-seal-check.sh", "scripts/intake-seal-check.sh"],
  ["5_executing/templates/agent-md-entry.md.tmpl", "templates/agent-md-entry.md.tmpl"],
  ...["conflict-probe.sh", "render-pr-body.mjs", "ci-poll.sh"].map(name => [`8_delivery/scripts/${name}`, `scripts/${name}`]),
  ["8_delivery/templates/pr-body.md.tmpl", "templates/pr-body.md.tmpl"],
  ...["wave-gate.sh", "quality-gate-proof.sh", "quality-evidence.mjs", "gen-component-registry.mjs"].map(name => [`5_executing/scripts/${name}`, `scripts/${name}`]),
];

function safePath(root, relative) {
  let current = root;
  for (const part of relative.split("/")) {
    if (!part || part === "." || part === "..") throw new Error(`invalid managed path: ${relative}`);
    current = path.join(current, part);
    if (fs.lstatSync(current, { throwIfNoEntry: false })?.isSymbolicLink()) {
      throw new Error(`refusing managed symlink: ${current}`);
    }
  }
  return current;
}

// Manifests written before CP1/P0 moved into 5_executing name the retired skill folders.
const currentSource = source => String(source)
  .replace(/^4b_setup\/(scripts|manifests)\//, "5_executing/$1/")
  .replace(/^4a_checkpoint\/(scripts|templates)\//, "5_executing/$1/");
const hash = bytes => createHash("sha256").update(bytes).digest("hex");
const signature = file => fs.existsSync(file) ? hash(fs.readFileSync(file)) : null;

function main() {
  let skills = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
  let target = process.cwd();
  let check = false;
  const adopted = new Set();
  const args = process.argv.slice(2);
  while (args.length) {
    const arg = args.shift();
    if (arg === "--check") check = true;
    else if (["--skills-root", "--target", "--adopt"].includes(arg) && args[0] && !args[0].startsWith("--")) {
      const value = args.shift();
      if (arg === "--skills-root") skills = path.resolve(value);
      else if (arg === "--target") target = path.resolve(value);
      else adopted.add(value);
    } else throw new Error("Usage: node <installed>/5_executing/scripts/sync-framework.mjs [--check] [--target REPO] [--skills-root SKILLS] [--adopt PATH]...");
  }
  if (check && adopted.size) throw new Error("--check cannot adopt changes");
  for (const name of adopted) {
    if (!inventory.some(([, destination]) => destination === name)) throw new Error(`not a managed path: ${name}`);
  }
  target = fs.realpathSync(target);
  skills = fs.realpathSync(skills);
  if (!fs.existsSync(path.join(skills, "5_executing/scripts/sync-framework.mjs"))) throw new Error("invoke the installed synchronizer, or supply --skills-root pointing to an installed skill tree");
  const git = (...command) => execFileSync("git", command, { cwd: target, encoding: "utf8" }).trim();
  if (fs.realpathSync(git("rev-parse", "--show-toplevel")) !== target) throw new Error("target must be the Git worktree root");
  const lock = git("rev-parse", "--path-format=absolute", "--git-path", "skillchain-helper-sync.lock");
  try { fs.mkdirSync(lock); } catch (error) {
    if (error.code === "EEXIST") throw new Error(`helper sync already locked: ${lock}; remove only after confirming no sync is running`);
    throw error;
  }
  try {
    const manifestPath = safePath(target, ".skillchain-helpers.json");
    const previous = fs.existsSync(manifestPath) ? JSON.parse(fs.readFileSync(manifestPath, "utf8")) : { version: 1, files: {} };
    if (previous.version !== 1 || !previous.files || typeof previous.files !== "object" || Array.isArray(previous.files)) throw new Error("invalid .skillchain-helpers.json");
    const next = { version: 1, files: {} };
    const updates = [], conflicts = [];
    for (const [source, destination] of inventory) {
      const from = safePath(skills, source), to = safePath(target, destination);
      if (!fs.statSync(from).isFile()) throw new Error(`installed helper missing: ${source}`);
      const bytes = fs.readFileSync(from);
      const sourceHash = hash(bytes), localHash = signature(to), old = previous.files[destination];
      const oldIsValid = old && currentSource(old.source) === source && /^[a-f0-9]{64}$/.test(old.source_hash) && /^[a-f0-9]{64}$/.test(old.local_hash);
      const unchanged = oldIsValid && old.local_hash === localHash;
      const reviewed = unchanged && old.source_hash === sourceHash;
      const replaceable = localHash === null || localHash === sourceHash || (unchanged && old.local_hash === old.source_hash);
      if (adopted.has(destination) && localHash === null) throw new Error(`cannot adopt missing file: ${destination}`);
      if (!replaceable && !reviewed && !adopted.has(destination)) {
        conflicts.push(`${destination} (${oldIsValid && old.source_hash !== sourceHash ? "upstream changed; reconcile local adaptation" : "untracked or modified local copy"})`);
        continue;
      }
      const keepLocal = adopted.has(destination) || !replaceable;
      const mode = fs.statSync(from).mode & 0o777;
      const needsCopy = !keepLocal && (localHash !== sourceHash || (fs.statSync(to).mode & 0o777) !== mode);
      if (needsCopy) updates.push({ bytes, to, mode, expected: localHash });
      next.files[destination] = { source, source_hash: sourceHash, local_hash: keepLocal ? localHash : sourceHash };
    }
    if (conflicts.length) {
      throw new Error(`no files changed; reconcile these helpers:\n${conflicts.join("\n")}\nCompare with the installed source. After merging and testing an adaptation, rerun with --adopt <path> for each reviewed file. Do not adopt an outdated copy merely to bypass this check.`);
    }
    const serialized = JSON.stringify(next, null, 2) + "\n";
    const manifestChanged = !fs.existsSync(manifestPath) || fs.readFileSync(manifestPath, "utf8") !== serialized;
    if (check) {
      if (updates.length || manifestChanged) throw new Error(`helper refresh required (${updates.length} files; manifest ${manifestChanged ? "needs update" : "current"}); run sync-framework.mjs without --check`);
      console.log("Framework helpers current (reviewed adaptations preserved).");
      return;
    }
    // Plan first: missing sources or conflicts above must not cause a partial refresh.
    for (const { bytes, to, mode, expected } of updates) {
      if (signature(to) !== expected) throw new Error(`file changed during sync: ${to}`);
      fs.mkdirSync(path.dirname(to), { recursive: true });
      fs.writeFileSync(to, bytes);
      fs.chmodSync(to, mode);
    }
    if (manifestChanged) {
      const pending = `${manifestPath}.tmp-${process.pid}`;
      fs.writeFileSync(pending, serialized, { flag: "wx" });
      fs.renameSync(pending, manifestPath);
    }
    console.log(`Framework helpers synchronized: ${updates.length} updated, ${Object.values(next.files).filter(v => v.source_hash !== v.local_hash).length} reviewed adaptations. Commit changed helpers and .skillchain-helpers.json before implementation.`);
  } finally { fs.rmdirSync(lock); }
}

try { main(); } catch (error) { console.error(`sync-framework: ${error.message}`); process.exitCode = 1; }
