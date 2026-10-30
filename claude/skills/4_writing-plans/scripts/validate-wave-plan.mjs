#!/usr/bin/env node
import fs, { realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { parseStories, PRD_FORMAT, resolveStories } from "./document-parser.mjs";
import { resolveInputs, checkExternalStories } from "./resolve-inputs.mjs";
const isText = (value) => typeof value === "string" && value.trim() !== "";
const clean = (value) => value.trim().replace(/^`|`$/g, "");
const normalizeCommand = (value) => value.trim().replace(/\s+/g, " ");
const sameSet = (left, right) =>
  left.size === right.size && [...left].every((value) => right.has(value));
const MAX_TASK_BODY_LINES = 55;
const NARRATED_DIFF_PATTERN = /Post-cross-review|an earlier draft/i;
const EMBEDDED_SQL_PATTERN =
  /\bRAISE EXCEPTION\b|\bCREATE (TABLE|TRIGGER|FUNCTION)\b|\bALTER TABLE\b|\bBEFORE (INSERT|UPDATE|DELETE)\b|\bUPDATE\s+\w+\s+SET\b|\bINSERT INTO\b/i;

function storiesMain(planFile) {
  if (!planFile) {
    console.error("usage: validate-wave-plan.mjs --stories <wave-plan.md>");
    process.exit(64);
  }
  try {
    checkExternalStories(resolveInputs(path.dirname(path.dirname(path.resolve(planFile)))), parseStories(fs.readFileSync(planFile, "utf8")));
    console.log(JSON.stringify(resolveStories(fs.readFileSync(planFile, "utf8"), planFile), null, 2));
  } catch (error) {
    console.error(`stories: ${error.message}`);
    process.exit(2);
  }
}

function validateMain(args) {
  if (args[0] === "--stories") return storiesMain(args[1]);
  const planDir = path.resolve(args[0] ?? "");
  const repoRoot = path.resolve(args[1] ?? path.join(planDir, "../../.."));
  const errors = [];
  const fail = (message) => errors.push(message);
  if (!args[0]) {
    console.error("usage: validate-wave-plan.mjs <3-4_plan-directory> [repository-root]");
    process.exit(2);
  }

  const configPath = path.join(planDir, "wave-gate-config.json");
  if (!fs.existsSync(configPath)) {
    console.error(`plan consistency: missing ${configPath}`);
    console.error("hint: this check takes the plan directory (specs/PROJ-<X>-<theme>/3-4_plan), not a PROJ number and theme");
    process.exit(1);
  }

  let config;
  try {
    config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  } catch (error) {
    console.error(`plan consistency: invalid JSON in ${configPath}: ${error.message}`);
    process.exit(1);
  }

  const planFiles = fs
    .readdirSync(planDir)
    .filter((name) => /^PROJ-.+-wave-\d+-plan\.md$/.test(name))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));

  if (planFiles.length === 0) fail("no PROJ-*-wave-<N>-plan.md files found");

  const plans = new Map();
  const allPlanAcs = new Map();
  const wordedAcs = [];

  for (const file of planFiles) {
    const wave = file.match(/-wave-(\d+)-plan\.md$/)?.[1];
    if (!wave) continue;
    if (plans.has(wave)) {
      fail(`wave ${wave}: more than one plan file`);
      continue;
    }

    const tasks = new Map();
    const acceptanceCriteria = new Set();
    let currentTask = null;
    let inFiles = false;
    let inGateCommands = false;

    const planText = fs.readFileSync(path.join(planDir, file), "utf8");
    const planAcs = parseStories(planText).flatMap(story => story.acs);
    wordedAcs.push(...planAcs.map(ac => ({ ...ac, file: path.join(planDir, file) })));
    for (const [index, line] of planText.split(/\r?\n/).entries()) {
      // External source examples are criterion data, never task or gate declarations.
      if (planAcs.some(ac => ac.externalLiteral && index + 1 > ac.line && index + 1 <= ac.literalEndLine)) continue;
      const taskMatch = line.match(/^### Task ([^:]+):/);
      if (taskMatch) {
        const task = `Task ${taskMatch[1].trim()}`;
        if (tasks.has(task)) fail(`wave ${wave}: duplicate task identifier ${task}`);
        currentTask = { fulfills: new Set(), testFiles: new Set(), commands: new Map(), body: [] };
        tasks.set(task, currentTask);
        inFiles = false;
        inGateCommands = false;
        continue;
      }

      const acMatch = line.match(/^- \[ \] ([A-Za-z0-9][A-Za-z0-9._-]*AC-[A-Za-z0-9._-]+):/);
      if (acMatch) {
        const id = acMatch[1];
        acceptanceCriteria.add(id);
        if (allPlanAcs.has(id)) {
          fail(`acceptance criterion ${id} appears more than once (${allPlanAcs.get(id)} and wave ${wave})`);
        } else {
          allPlanAcs.set(id, wave);
        }
      }

      if (currentTask) currentTask.body.push(line);
      if (!currentTask) continue;
      const fulfillsMatch = line.match(/^\*\*Fulfills:\*\*\s*(.+)$/);
      if (fulfillsMatch) {
        for (const id of fulfillsMatch[1].split(",").map(clean).filter(Boolean)) {
          currentTask.fulfills.add(id);
        }
        inFiles = false;
        inGateCommands = false;
        continue;
      }
      if (line === "**Files:**") {
        inFiles = true;
        inGateCommands = false;
        continue;
      }
      if (line === "**Gate commands:**") {
        inFiles = false;
        inGateCommands = true;
        continue;
      }
      if (/^(###|##|\*\*)/.test(line)) {
        inFiles = false;
        inGateCommands = false;
      }
      if (inFiles) {
        const testMatch = line.match(/^- Test(?: \([^)]*\))?:\s*(.+)$/);
        if (testMatch) currentTask.testFiles.add(clean(testMatch[1]));
      }
      if (inGateCommands) {
        const commandMatch = line.match(/^- `?([A-Za-z0-9][A-Za-z0-9._-]*AC-[A-Za-z0-9._-]+)`?:\s*`(.+)`\s*$/);
        if (commandMatch) {
          const [, id, command] = commandMatch;
          if (currentTask.commands.has(id)) fail(`wave ${wave}: duplicate gate command for ${id}`);
          currentTask.commands.set(id, command);
        }
      }
    }

    const fulfillingTasks = new Map();
    for (const [task, metadata] of tasks) {
      if (metadata.fulfills.size === 0) fail(`wave ${wave} ${task}: missing Fulfills metadata`);
      if (metadata.testFiles.size === 0) fail(`wave ${wave} ${task}: missing Test entry in Files`);
      for (const id of metadata.fulfills) {
        if (!acceptanceCriteria.has(id)) fail(`wave ${wave} ${task}: Fulfills references undeclared AC ${id}`);
        const owners = fulfillingTasks.get(id) ?? [];
        owners.push(task);
        fulfillingTasks.set(id, owners);
        if (!metadata.commands.has(id)) fail(`wave ${wave} ${task}: missing Gate command for ${id}`);
      }
      for (const id of metadata.commands.keys()) {
        if (!metadata.fulfills.has(id)) fail(`wave ${wave} ${task}: Gate command ${id} is absent from Fulfills`);
      }
      const bodyText = metadata.body.join("\n");
      const bodyLines = metadata.body.filter((line) => line.trim() !== "").length;
      if (bodyLines > MAX_TASK_BODY_LINES) {
        fail(`wave ${wave} ${task}: task body is ${bodyLines} non-blank lines (max ${MAX_TASK_BODY_LINES}) — over-specified; split it or move migration/DDL detail to migration-design.md and cite it`);
      }
      if (NARRATED_DIFF_PATTERN.test(bodyText)) {
        fail(`wave ${wave} ${task}: contains narrated-diff scaffolding ("Post-cross-review"/"an earlier draft") — reconcile review feedback by rewriting the task, not by appending review history`);
      }
      if (EMBEDDED_SQL_PATTERN.test(bodyText)) {
        fail(`wave ${wave} ${task}: contains literal SQL/DDL — describe the resulting behaviour in prose, or cite migration-design.md by decision`);
      }
    }
    for (const id of acceptanceCriteria) {
      const owners = fulfillingTasks.get(id) ?? [];
      if (owners.length !== 1) {
        fail(`wave ${wave}: acceptance criterion ${id} must be fulfilled by exactly one task (found ${owners.length})`);
      }
    }
    plans.set(wave, { acceptanceCriteria, tasks });
  }

  // AC wording, byte-exact after the checkbox/ID prefix except for line endings (CRLF = LF), the
  // trailing whitespace of each line, trailing blank lines and the leading spaces of the first
  // line (all dropped by parseStories on both sides): plan PROJ-X-PRD-Y-US-Z-AC-N against
  // AC-N under US-Z in ../2_PRDs/PROJ-X-PRD-Y-*.md (first entry wins). Several such files (e.g. a
  // stray copy): the one whose first H1 is `# PROJ-X-PRD-Y` (or `# PROJ-X PRD-Y`) wins; 2c's
  // `<prd-stem>-review-decisions.md` never counts. No 2_PRDs/ directory: legacy, note only.
  let external;
  try {
    external = resolveInputs(path.dirname(planDir));
    checkExternalStories(external, planFiles.flatMap(file => parseStories(fs.readFileSync(path.join(planDir, file), "utf8"))), { complete: true });
  } catch (error) { fail(error.message); external = true; }
  const prdDir = path.join(planDir, "..", "2_PRDs");
  if (external) { /* The receiving contract replaces only the local PRD-format input gate. */ }
  else if (!fs.statSync(prdDir, { throwIfNoEntry: false })?.isDirectory()) {
    if (wordedAcs.length) console.error(`note: AC wording not compared against PRDs: ${prdDir} is not a directory (legacy project)`);
  } else {
    const prdNames = fs.readdirSync(prdDir).filter((name) => name.endsWith(".md") && !name.endsWith("-review-decisions.md"));
    const titleOf = (name) => fs.readFileSync(path.join(prdDir, name), "utf8").match(/^# .*$/m)?.[0].match(/^# PROJ-(.+?)[- ]PRD-(\d+)(?!\d)/)?.slice(1).join("/");
    const prdStories = new Map();
    for (const ac of wordedAcs) {
      const plan = `${ac.file}:${ac.line}: ${JSON.stringify(ac.text)}`;
      const [, x, y, us, acId] = ac.id.match(/^PROJ-(.+)-PRD-(\d+)-US-(\d+)-(AC-[A-Za-z0-9._-]+)$/) ?? [];
      if (!acId) { fail(`${ac.id}: no PRD entry, the ID does not follow PROJ-<X>-PRD-<Y>-US-<Z>-AC-<N>\n    plan ${plan}`); continue; }
      let names = prdNames.filter((name) => name.startsWith(`PROJ-${x}-PRD-${y}-`));
      if (names.length > 1) names = names.filter((name) => titleOf(name) === `${x}/${y}`);
      if (names.length !== 1) { fail(`${ac.id}: no PRD entry, expected one ${path.join(prdDir, `PROJ-${x}-PRD-${y}-*.md`)} (titled # PROJ-${x}-PRD-${y} if several), found ${names.length}\n    plan ${plan}`); continue; }
      const prdFile = path.join(prdDir, names[0]);
      if (!prdStories.has(prdFile)) prdStories.set(prdFile, parseStories(fs.readFileSync(prdFile, "utf8"), PRD_FORMAT));
      const prdAc = prdStories.get(prdFile).find((story) => story.id === `US-${us}`)?.acs.find((entry) => entry.id === acId);
      if (!prdAc) fail(`${ac.id}: no PRD entry (${acId} under US-${us})\n    plan ${plan}\n    PRD  ${prdFile}: (missing)`);
      else if (prdAc.text !== ac.text) fail(`${ac.id}: plan wording differs from the PRD\n    plan ${plan}\n    PRD  ${prdFile}:${prdAc.line}: ${JSON.stringify(prdAc.text)}`);
    }
  }

  if (!config || typeof config !== "object" || Array.isArray(config)) {
    fail("config root must be an object");
  }
  const waves = config?.waves;
  if (!waves || typeof waves !== "object" || Array.isArray(waves)) {
    fail("config.waves must be an object");
  }
  if (Object.hasOwn(config ?? {}, "sonar_required") && typeof config.sonar_required !== "boolean") {
    fail("sonar_required must be boolean when present");
  }
  if (Object.hasOwn(config ?? {}, "coderabbit")) {
    const cr = config.coderabbit;
    if (!cr || typeof cr !== "object" || Array.isArray(cr) || !Object.keys(cr).every((k) => k === "enabled") || (Object.hasOwn(cr, "enabled") && typeof cr.enabled !== "boolean")) {
      fail("coderabbit must be an object with an optional boolean 'enabled'");
    }
  }
  if (!isText(config?.sonar_cmd)) {
    fail("sonar_cmd must be a non-empty top-level string");
  }

  const configuredAcs = new Map();
  const regressionFilesByWave = new Map();
  let hasAuthConsumingCommand = false;

  for (const [wave, plan] of plans) {
    const waveConfig = waves?.[wave];
    if (!waveConfig || typeof waveConfig !== "object" || Array.isArray(waveConfig)) {
      fail(`wave ${wave}: missing config.waves.${wave}`);
      continue;
    }

    const acCommands = waveConfig.ac_commands;
    const acEvidence = [];
    if (!Array.isArray(acCommands) || acCommands.length === 0) {
      fail(`wave ${wave}: ac_commands must be a non-empty array`);
    } else {
      acCommands.forEach((entry, index) => {
        const label = `wave ${wave} ac_commands[${index}]`;
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
          fail(`${label}: legacy string entries are unsupported; replace each with {id, task, command, test_files, auth_consuming}`);
          return;
        }
        for (const key of ["id", "task", "command"]) {
          if (!isText(entry[key])) fail(`${label}: ${key} must be a non-empty string`);
        }
        if (Object.hasOwn(entry, "external_dependency")) {
          const dependency = entry.external_dependency;
          if (!dependency || typeof dependency !== "object" || Array.isArray(dependency)) {
            fail(`${label}: external_dependency must be an object`);
          } else {
            for (const key of ["reason", "decided_by", "decided_at", "check_command"]) {
              if (!isText(dependency[key])) fail(`${label}: external_dependency.${key} must be non-empty`);
            }
            if (!/^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(dependency.decided_at ?? "") || !Number.isFinite(Date.parse(dependency.decided_at))) {
              fail(`${label}: external_dependency.decided_at must be an ISO timestamp with timezone`);
            }
          }
        }
        if (isText(entry.command) && /&&|\|\||;/.test(entry.command)) {
          fail(`${label}: must invoke exactly one test runner; split shell-chained commands`);
        }
        if (typeof entry.auth_consuming !== "boolean") {
          fail(`${label}: auth_consuming must be boolean`);
        } else if (entry.auth_consuming) {
          hasAuthConsumingCommand = true;
          if (!isText(entry.wave_required_reason)) {
            fail(`${label}: wave_required_reason must explain why hosted auth is needed before CI`);
          }
        }
        if (!Array.isArray(entry.test_files) || entry.test_files.length === 0 || !entry.test_files.every(isText)) {
          fail(`${label}: test_files must be a non-empty string array`);
        }

        if (isText(entry.id)) {
          if (configuredAcs.has(entry.id)) {
            fail(`acceptance criterion ${entry.id} has more than one configured command`);
          } else {
            configuredAcs.set(entry.id, wave);
          }
          if (!plan.acceptanceCriteria.has(entry.id)) {
            fail(`${label}: id ${entry.id} is not declared in the wave ${wave} plan`);
          }
        }

        const task = isText(entry.task) ? plan.tasks.get(entry.task) : null;
        if (isText(entry.task) && !task) fail(`${label}: task ${entry.task} does not exist in the wave ${wave} plan`);
        if (task && isText(entry.id) && !task.fulfills.has(entry.id)) {
          fail(`${label}: task ${entry.task} does not fulfill ${entry.id}`);
        }
        if (task && isText(entry.id) && isText(entry.command) && task.commands.get(entry.id) !== entry.command) {
          fail(`${label}: command differs from ${entry.task} Gate command for ${entry.id}`);
        }
        if (task && Array.isArray(entry.test_files) && entry.test_files.every(isText)) {
          const configuredFiles = new Set(entry.test_files.map(clean));
          if (!sameSet(configuredFiles, task.testFiles)) {
            fail(`${label}: test_files differ from ${entry.task} Files/Test entries (config: ${[...configuredFiles].join(", ")}; plan: ${[...task.testFiles].join(", ")})`);
          }
        }
        if (isText(entry.command) && Array.isArray(entry.test_files) && entry.test_files.length > 0 && entry.test_files.every(isText)) {
          acEvidence.push({ command: normalizeCommand(entry.command), testFiles: new Set(entry.test_files.map(clean)) });
        }
      });
    }

    const regressions = waveConfig.regression_commands;
    const regressionFiles = new Set();
    regressionFilesByWave.set(wave, regressionFiles);
    if (!Array.isArray(regressions) || regressions.length === 0) {
      fail(`wave ${wave}: regression_commands must declare at least one broad regression suite`);
    } else {
      regressions.forEach((entry, index) => {
        const label = `wave ${wave} regression_commands[${index}]`;
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
          fail(`${label}: must be a structured object`);
          return;
        }
        for (const key of ["label", "command"]) {
          if (!isText(entry[key])) fail(`${label}: ${key} must be a non-empty string`);
        }
        if (Object.hasOwn(entry, "selection_check_cmd") && !isText(entry.selection_check_cmd)) {
          fail(`${label}: selection_check_cmd must be a non-empty string`);
        }
        if (isText(entry.command) && /&&|\|\||;/.test(entry.command)) {
          fail(`${label}: must invoke exactly one test runner; split shell-chained commands`);
        }
        if (!Array.isArray(entry.test_files) || entry.test_files.length === 0 || !entry.test_files.every(isText)) {
          fail(`${label}: test_files must be a non-empty string array`);
        } else {
          const entryFiles = new Set(entry.test_files.map(clean));
          entryFiles.forEach((file) => regressionFiles.add(file));
          if (
            isText(entry.command) &&
            acEvidence.some(
              (ac) => ac.command === normalizeCommand(entry.command) && sameSet(ac.testFiles, entryFiles),
            )
          ) {
            fail(`${label}: duplicates an AC command and test_files set; this is not broad regression coverage`);
          }
        }
        if (typeof entry.auth_consuming !== "boolean") {
          fail(`${label}: auth_consuming must be boolean`);
        } else if (entry.auth_consuming) {
          hasAuthConsumingCommand = true;
          if (!isText(entry.wave_required_reason)) {
            fail(`${label}: wave_required_reason must explain why hosted auth is needed before CI`);
          }
        }
        if (Object.hasOwn(entry, "reuse_passed") && typeof entry.reuse_passed !== "boolean") {
          fail(`${label}: reuse_passed must be boolean when present`);
        }
        if (entry.reuse_passed === true && entry.auth_consuming === true) {
          fail(`${label}: reuse_passed cannot cache auth-consuming commands`);
        }
        if (
          Object.hasOwn(entry, "require_non_empty_selection") &&
          typeof entry.require_non_empty_selection !== "boolean"
        ) {
          fail(`${label}: require_non_empty_selection must be boolean when present`);
        }
      });
    }
  }

  const relPath = (v) => isText(v) && !path.isAbsolute(v) && !v.split(/[\\/]/).includes("..");
  if (config.app_root !== undefined && !relPath(config.app_root)) fail("app_root must be a relative path without '..'");
  if (config.worktree_links !== undefined) {
    const links = config.worktree_links;
    if (!Array.isArray(links) || !links.length || !links.every((l) => l && typeof l === "object" && relPath(l.path) && relPath(l.target))) {
      fail("worktree_links must be a non-empty array of {path, target}, both relative paths without '..'");
    }
  }
  if (config.resources !== undefined) {
    const r = config.resources;
    const keys = ["min_available_mb", "max_memory_psi_full_avg10", "wait_seconds", "test_workers", "max_parallel_commands"];
    if (!r || typeof r !== "object" || Array.isArray(r) || !Object.keys(r).every((k) => keys.includes(k)) || !Object.values(r).every((v) => Number.isInteger(v) && v >= 0) || r.test_workers === 0 || r.max_parallel_commands === 0) {
      fail(`resources must be an object with non-negative integers (test_workers and max_parallel_commands > 0) from: ${keys.join(", ")}`);
    }
  }
  for (const key of ["coverage_cmd", "lint_cmd", "complexity_cmd", "arch_rules_cmd", "mutation_cmd"]) {
    if (config[key] !== undefined && !isText(config[key])) fail(`${key} must be a non-empty string`);
  }
  for (const key of ["build_artifacts", "coverage_artifacts"]) {
    if (config[key] !== undefined && (!Array.isArray(config[key]) || !config[key].length || !config[key].every(isText))) fail(`${key} must be a non-empty string array`);
  }
  if (config.coverage_cmd && !config.coverage_artifacts?.length) fail("coverage_cmd requires coverage_artifacts");
  const qualityLabels = new Set();
  for (const entry of Array.isArray(config.phase_commands) ? config.phase_commands : []) {
    if (entry?.phase !== "quality") continue;
    if (qualityLabels.has(entry.label)) fail(`duplicate quality command label: ${entry.label}`);
    qualityLabels.add(entry.label);
    if (config.coverage_cmd && entry.command === config.coverage_cmd) fail("coverage_cmd must not also run as a quality phase command");
  }

  const phaseCommands = config.phase_commands;
  if (phaseCommands !== undefined) {
    if (!Array.isArray(phaseCommands)) {
      fail("phase_commands must be an array when present");
    } else {
      phaseCommands.forEach((entry, index) => {
        const label = `phase_commands[${index}]`;
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
          fail(`${label}: must be a structured object`);
          return;
        }
        for (const key of ["label", "command"]) {
          if (!isText(entry[key])) fail(`${label}: ${key} must be a non-empty string`);
        }
        if (!isText(entry.phase) || !["quality", "ci", "nightly"].includes(entry.phase)) {
          fail(`${label}: phase must be quality, ci, or nightly`);
        }
        if (!Array.isArray(entry.test_files) || entry.test_files.length === 0 || !entry.test_files.every(isText)) {
          fail(`${label}: test_files must be a non-empty string array`);
        }
        if (typeof entry.auth_consuming !== "boolean") {
          fail(`${label}: auth_consuming must be boolean`);
        }
        if (["ci", "nightly"].includes(entry.phase) && !isText(entry.workflow_file)) {
          fail(`${entry.phase} phase command requires workflow_file`);
        } else if (["ci", "nightly"].includes(entry.phase)) {
          const workflowPath = path.resolve(repoRoot, entry.workflow_file);
          if (!fs.existsSync(workflowPath)) {
            fail(`${label}: workflow_file does not exist: ${entry.workflow_file}`);
          } else if (
            isText(entry.command) &&
            !fs
              .readFileSync(workflowPath, "utf8")
              .split(/\r?\n/)
              .some((line) => !/^\s*#/.test(line) && line.includes(entry.command))
          ) {
            fail(`${label}: command is absent from workflow_file ${entry.workflow_file}`);
          }
        }
      });
    }
  }

  for (const wave of Object.keys(waves ?? {})) {
    if (!plans.has(wave)) fail(`config.waves.${wave} has no matching wave plan`);
  }
  for (const [id, wave] of allPlanAcs) {
    if (!configuredAcs.has(id)) fail(`acceptance criterion ${id} from wave ${wave} has no configured command`);
  }

  if (Object.hasOwn(config, "auth_provider_rate_limited") && typeof config.auth_provider_rate_limited !== "boolean") {
    fail("auth_provider_rate_limited must be boolean when present");
  }
  const authBudget = config.auth_budget;
  if (hasAuthConsumingCommand || config.auth_provider_rate_limited === true || authBudget !== undefined) {
    if (!authBudget || typeof authBudget !== "object" || Array.isArray(authBudget)) {
      fail("auth-consuming commands or rate-limited hosted auth require config.auth_budget");
    } else {
      if (!isText(authBudget.preflight_cmd)) fail("auth_budget.preflight_cmd must be a non-empty string");
      if (config.auth_provider_rate_limited === true && !isText(authBudget.rate_limit_evidence_cmd)) {
        fail("rate-limited hosted auth requires auth_budget.rate_limit_evidence_cmd for failures outside the test log");
      }
      if (!Number.isInteger(authBudget.exhausted_exit_code) || authBudget.exhausted_exit_code < 1 || authBudget.exhausted_exit_code > 255) {
        fail("auth_budget.exhausted_exit_code must be an integer from 1 to 255 (default 75)");
      }
    }
  }

  const frontend = config.frontend;
  if (frontend !== undefined) {
    if (!frontend || typeof frontend !== "object" || Array.isArray(frontend)) {
      fail("frontend must be an object");
    } else {
      const routes = frontend.routes;
      if (!Array.isArray(routes)) {
        fail("frontend.routes must be an array");
      } else if (routes.length > 0) {
        if (!isText(frontend.dev_cmd)) fail("frontend.dev_cmd must be a non-empty string when routes are configured");
        if (!isText(frontend.dev_url)) fail("frontend.dev_url must be a non-empty string when routes are configured");
        const readiness = frontend.readiness;
        if (!readiness || typeof readiness !== "object" || Array.isArray(readiness)) {
          fail("frontend.readiness must be an object when routes are configured");
        } else {
          if (!isText(readiness.path)) fail("frontend.readiness.path must be a non-empty string");
          for (const key of ["timeout_seconds", "interval_seconds"]) {
            if (!Number.isInteger(readiness[key]) || readiness[key] <= 0) fail(`frontend.readiness.${key} must be a positive integer`);
          }
        }
        routes.forEach((route, index) => {
          const label = `frontend.routes[${index}]`;
          if (!route || typeof route !== "object" || Array.isArray(route)) {
            fail(`${label}: must be an object`);
            return;
          }
          const wave = String(route.wave ?? "");
          if (!plans.has(wave)) fail(`${label}: wave must name an existing wave`);
          for (const key of ["path", "expected_url", "expected_text"]) {
            if (!isText(route[key])) fail(`${label}: ${key} must be a non-empty string`);
          }
          if (isText(route.path) && isText(route.expected_url) && isText(frontend.dev_url)) {
            try {
              const requestedPath = new URL(route.path, frontend.dev_url).pathname;
              const expectedPath = new URL(route.expected_url, frontend.dev_url).pathname;
              if (requestedPath !== expectedPath) {
                fail(`${label}: expected_url must retain route path ${requestedPath}; redirects are not smoke success`);
              }
            } catch {
              fail(`${label}: path and expected_url must be valid URL references`);
            }
          }
          if (typeof route.protected !== "boolean") fail(`${label}: protected must be boolean`);
          const e2eFiles = route.authenticated_e2e_test_files;
          if (e2eFiles !== undefined && (!Array.isArray(e2eFiles) || e2eFiles.length === 0 || !e2eFiles.every(isText))) {
            fail(`${label}: authenticated_e2e_test_files must be a non-empty string array when present`);
          }
          if (Array.isArray(e2eFiles) && e2eFiles.every(isText) && plans.has(wave)) {
            for (const file of e2eFiles.map(clean)) {
              if (!regressionFilesByWave.get(wave)?.has(file) && !waves[wave]?.ac_commands?.some((ac) => Array.isArray(ac.test_files) && ac.test_files.map(clean).includes(file))) {
                fail(`${label}: authenticated E2E file ${file} is absent from wave ${wave} AC/regression test_files`);
              }
            }
          }
          const hasE2eCoverage = Array.isArray(e2eFiles) && e2eFiles.length > 0 && e2eFiles.every(isText);
          if (route.protected === true && !isText(route.auth_state) && !hasE2eCoverage) {
            fail(`${label}: protected routes require auth_state or authenticated_e2e_test_files`);
          }
        });
      }
    }
  }

  if (errors.length > 0) {
    console.error("wave plan consistency failed:");
    errors.forEach((error) => console.error(`- ${error}`));
    process.exit(1);
  }

  console.log(`wave plan consistency passed: ${plans.size} wave(s), ${allPlanAcs.size} AC(s)`);
}

const isMain = () => { try { return realpathSync(process.argv[1]) === fileURLToPath(import.meta.url); } catch { return false; } };
if (isMain()) validateMain(process.argv.slice(2));
