# wave-gate-config.json

Feeds `chain gate wave` (Skill 5); its commands are the ones Ralph runs. Structure
is enforced by `chain check plan` — write from the example, run the
validator, fix what it reports. This file covers only what it cannot check.

```json
{
  "build_cmd": "npm run build",
  "sonar_cmd": "npm run sonar",
  "timeouts": { "ac_seconds": 300, "ralph_stall_seconds": 300, "build_seconds": 600, "coderabbit_seconds": 600, "browser_seconds": 120 },
  "auth_provider_rate_limited": true,
  "auth_budget": { "preflight_cmd": "npm run auth:budget-check", "rate_limit_evidence_cmd": "npm run auth:rate-limit-check", "exhausted_exit_code": 75 },
  "frontend": {
    "dev_cmd": "npm run dev",
    "dev_url": "http://localhost:3000",
    "readiness": { "path": "/health", "timeout_seconds": 60, "interval_seconds": 2 },
    "routes": [{ "wave": "1", "path": "/account", "expected_url": "http://localhost:3000/account", "expected_text": "Your account", "protected": true, "auth_state": "tests/e2e/.auth/user.json" }]
  },
  "phase_commands": [{ "label": "hosted browser auth regression", "phase": "nightly", "command": "npm run test:e2e -- tests/e2e/auth.spec.ts", "test_files": ["tests/e2e/auth.spec.ts"], "auth_consuming": true, "workflow_file": ".github/workflows/e2e.yml" }],
  "waves": {
    "1": {
      "codex_effort": "high",
      "advisory_severities": ["medium", "low"],
      "ac_commands": [{ "id": "PROJ-1-PRD-1-US-1-AC-1", "task": "Task PROJ-1-PRD-1-US-1-T1", "command": "npm test -- src/auth/password.test.ts", "test_files": ["src/auth/password.test.ts"], "auth_consuming": false }],
      "regression_commands": [{ "label": "auth regression suite", "command": "npm test -- src/auth", "test_files": ["src/auth/password.test.ts", "src/auth/session.test.ts"], "auth_consuming": false, "require_non_empty_selection": true }]
    }
  }
}
```

Optional top-level keys: `lint_cmd` (default `npm run lint`), `build_artifacts` (final-wave build reuse, deterministic builds only), `coverage_cmd` + `coverage_artifacts` (split coverage out of a Sonar wrapper; `sonar_cmd` then stays scanner-only). `sonar_cmd` is the repo's real entry point, run once at the PROJ-end Quality Gate. `complexity_cmd` and `arch_rules_cmd` (both optional strings) are static checks the wave gate runs last in the AC pass, once the ACs are green, with `WAVE_BASE_SHA` in the environment; absent → skipped. Each must exit 0 and print an analysed-file count above zero (`Analysed N files`, `N files checked`, `N modules cruised`), otherwise the gate fails it as a silent no-op. Optional `timeouts.complexity_seconds` / `arch_rules_seconds` default to `ac_seconds`. `mutation_cmd` (optional string) runs once at the PROJ-end Quality Gate, never per wave: it gets `BASE_SHA` (the P0 base tag) and `CHANGED_FILES_FILE` (absolute path to a temporary NUL-separated file list from `git diff -z --name-only --diff-filter=d BASE_SHA..HEAD`, deletions excluded) in its environment and must scope itself to them, must print the mutants tested (`Mutants: N`, positive control) and the survivors (`Survivors: N`), and exit 0 = threshold met, exactly 1 = survivors (with `Survivors: N` above zero; exit 1 without it is no evidence), any other non-zero = failed run (wrap tools whose exit codes differ; gitignore their temp and report directories); set `timeouts.mutation_seconds` explicitly. `timeouts` needs `ac_seconds`, `build_seconds`, `coderabbit_seconds`, `browser_seconds` — the gate (not the validator) fails without them; `ralph_stall_seconds` is optional (defaults to `ac_seconds`). `coderabbit_seconds` is only required while CodeRabbit is enabled (see `coderabbit` below).

**`coderabbit` (optional top-level object, `{ "enabled": false }`).** Absent, `{}` or `enabled: true` = today's behavior: CodeRabbit is a hard tool and the mandatory per-wave review. `enabled: false` switches only the CodeRabbit part of the wave gate's build/review phase off: the build still runs (same timeout, log, failure handling), but there is no `coderabbit review`, no 150-file scope limit, no normalization and no CodeRabbit ledger ingest. `timeouts.coderabbit_seconds` becomes optional (still validated if present); `advisory_severities` is ignored (the gate then treats every open ledger finding as blocking). Preflight skips the `coderabbit` tool and auth hard checks, and setup does not copy `.coderabbit.yaml`. The gate logs `CodeRabbit: DISABLED by wave-gate-config (coderabbit.enabled=false)` and writes the same line into the PASSED block instead of `attempt N ingested`. Any other shape (non-boolean `enabled`, unknown sub-key, non-object) is a config error (gate exit 64; validator and preflight reject it), never a silent skip. **Cost of `false`:** no automatic code review runs in the wave gate; ACs, declared regressions, smoke, static checks, build and the PROJ-end Quality Gate (with QA) remain. Never set it automatically: only when the user explicitly asks for it.

Host resources: optional `resources` (`{"min_available_mb":1024,"max_memory_psi_full_avg10":20,"wait_seconds":300,"max_parallel_commands":2,"test_workers":2}`; every key optional, defaults as shown except `test_workers`). The shared `compat.sh` admission guard checks ACs, regressions, builds, reviews, static checks and browser launches. It reads `MemAvailable` capped by the active cgroup v2 path from `/proc/self/cgroup` and its limiting ancestors and memory pressure-stall `full avg10`; macOS uses free + inactive + speculative pages from `vm_stat` without PSI. Missing telemetry is reported and command-capacity admission continues. Low headroom/pressure waits at most `wait_seconds`, then returns infrastructure exit 77 without launching the command; wave gates record `infrastructure_failed` and do not certify that command. `wait_seconds:0` checks immediately; zero memory/PSI thresholds are valid. Invalid, unknown or null policy values return configuration error 64; both worker/cap counts must be positive integers. `test_workers` exports `VITEST_MAX_WORKERS` while preserving an explicit existing value; CLI worker flags and other test runners remain configured in their commands.

`resource_run CONFIG LABEL command args…` reserves one shared host slot for the admitted command tree until it exits, with default capacity 2 so build and review can overlap. Nested guarded calls with a live inherited lease recheck headroom and share that slot. `resource_check CONFIG LABEL` performs admission only for model orchestrators that launch guarded tools. Use the same `max_parallel_commands` policy across participating commands on one host; this pool does not control unrelated processes or arbitrary nested tool parallelism and is not an OOM guarantee. Locks live in a private per-user temporary directory; on systems without kernel locks, interrupted-process cleanup releases portable mkdir slots, but an uncatchable kill can leave a stale slot that must be removed after verifying its owner is gone. No existing process is killed to create headroom, and timeout/exit codes are never interpreted as proof of OOM.

Nested app: optional `app_root` (relative directory, no `..`, default `.`) names the directory holding `package.json` and the lockfile. `chain worktree prepare` installs there, preflight checks the package manager there, and the wave gate's registry check scans `<app_root>/src`. Optional `worktree_links` (`[{"path": "1d_prototypes/x/node_modules", "target": "app/node_modules"}]`, both relative, `path` git-ignored) makes `prepare` recreate ignored dev-asset symlinks after the install, because a fresh worktree has none; `target` must exist after the install. Declared links are tolerated by cleanup; any other ignored payload still retains the worktree.

Sonar policy: optional `sonar_required` must be a boolean. Analysis is required when it is `true` or root `sonar-project.properties` exists; `false` never overrides project configuration. A wrapper/alternate properties path without root `sonar-project.properties`, or an explicit user requirement, must set `sonar_required: true`. Keep the required non-empty `sonar_cmd` even for optional, unconfigured projects: its presence alone does not require analysis. P0 hard-fails missing scanner engine/auth for required analysis; otherwise it records `sonar: project not configured` in its preflight skips. Quality Gate refuses both Sonar skip reasons for required analysis; missing prerequisites stop the run.

## Judgment rules

- **Static checks (`complexity_cmd`, `arch_rules_cmd`):** the project supplies the command; thresholds live in the tool's own config, not here. Set them looser than for humans at first (agents hold more in short-term memory) and tighten with evidence from `Variant Notes`. `complexity_cmd` covers complexity/duplication rules on the wave's changed files; `arch_rules_cmd` enforces the dependency direction `3_architecture` records. Wrap the real tool in a script that prints the analysed-file count when it does not. Failures are gate failures with verbatim tool output, not ledger findings.

- **AC commands:** cheapest deterministic proof of the new behaviour. Output must print a selected-test count (`Running N tests`, `Tests N passed`, `# tests N`, `N passed`) — zero/unparseable blocks. Auth-consuming only when the story changes auth or nothing cheaper proves it.
- **Regressions:** smallest suite covering shared behaviour the wave actually touches — not a replay of prior ACs, auth suites, or the E2E inventory, and never full-file AC coverage repeated inside a larger command. `require_non_empty_selection: true` for runners that can silently select nothing. `reuse_passed: true` only for deterministic local suites, never auth, browser, or external-DB checks; clear cached Ralph evidence after dependency, runtime, or environment changes. Filtered browser suites add a read-only `selection_check_cmd` using the same selector, listing tests without browser/DB/auth and printing a supported positive count (e.g. `Running 3 tests`); the gate runs it in Phase 0, before ACs.
- **Phase commands:** full hosted-auth and Playwright suites go here (`quality` runs once after all waves; `ci`/`nightly` name the workflow running that exact command). Deferral never replaces the wave's own AC proof.
- **Auth hooks:** `preflight_cmd` exits `exhausted_exit_code` (75) when the budget is gone. `rate_limit_evidence_cmd` runs after a failed auth-consuming command and checks provider/server state outside the test log: `0` + decisive evidence = rate-limited, `1` = not, other = infra failure; gets `WAVE`, `WAVE_GATE_CONFIG`, `RALPH_STATE`, `AC_ID`, `AC_LOG`. With `SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL=1`, preflight reports exhaustion without consuming an identity and the evidence hook exits 0 with simulated evidence.
- **Routes:** `authenticated_e2e_test_files` (instead of `auth_state`) only if that scenario really verifies the route. A redirect to login is never smoke success. Omit `frontend` for backend-only PROJs.
- **`advisory_severities`** (non-blocking CodeRabbit levels; ignored when `coderabbit.enabled` is `false`): `["medium","low"]` normally; add `high` only for low-risk polish/doc/test waves; never `critical`/`blocker`/`error` without explicit user acceptance. **`codex_effort`:** default `high`, `medium` for polish waves.
- **`external_dependency`** on an AC awaiting a named external approval (`reason`, `decided_by`, `decided_at`, `check_command`): keep the AC's command and test mapping unchanged and runnable once approved; record the real decision in `decisions.md`, never invent it. The read-only checker returns 0 only for a valid approval matching the current scope/revision, 76 = absent, other = checker failure. The gate marks the AC `blocked_external` and returns 76 without certifying the wave or unlocking dependents. To continue independent work, replan dependencies; never descope the AC.
- **Test file size:** the gate prints an advisory warning for any declared AC or regression test file above 800 lines. It never fails the gate and never splits the file; split only at a planned boundary and update task, config and route mappings together.
- **Browser files:** one scenario file per wave or cohesive feature with a named owner (e.g. `tests/e2e/wave-<N>.test.mjs`); keep wave fixture cleanup with its scenarios; list shared helpers that affect the proof in both task `Test:` and `test_files`; use the project's runner (`node --test` only without inherited lock descriptors). Don't split existing suites automatically: a deliberate split updates task/config/route mappings together, reruns the affected suites, invalidates cached evidence, and keeps old certificates as historical proof only. Refresh helpers at a quiet setup/resume boundary before using new config fields — old gates ignore them and cannot enforce their contracts.
- **Legacy string `ac_commands`:** convert by hand (regression and auth choices need judgment), re-validate, get approval again.

## Mutation wrapper scope (breaking change)

`CHANGED_FILES` is no longer exported, even if the parent shell sets it. Existing wrappers must migrate to `CHANGED_FILES_FILE`; there is no legacy or whole-repo fallback. The list exists only during the command and is removed after success, wrapper failure, timeout, or handled cancellation (SIGINT, SIGTERM, SIGHUP, SIGQUIT). Abrupt termination of the helper itself (for example SIGKILL or a runtime crash) may leave its private temporary directory behind. Read NUL records without line splitting, shell expansion, or `eval`; an empty list must never mean “mutate everything”. For example, adapt this Bash wrapper to the project's mutation tool:

```bash
set -euo pipefail
: "${BASE_SHA:?missing mutation base}" "${CHANGED_FILES_FILE:?missing mutation file list}"
[[ -f "$CHANGED_FILES_FILE" && -r "$CHANGED_FILES_FILE" ]] || exit 2
mapfile -d '' -t changed_files < "$CHANGED_FILES_FILE"
((${#changed_files[@]} > 0)) || { echo 'No changed files; no mutation scope' >&2; exit 2; }
# Pass the array to the real tool's file-selection interface; retain its scope.
# Example for a tool accepting literal paths after --:
# project-mutation-tool -- "${changed_files[@]}"
# Normalize its exit status and print actual Mutants: N and Survivors: N counts.
```

Filter unsupported file types explicitly inside the wrapper. If none remain, fail with an explanation; never silently widen the scope. Do not persist or reuse `CHANGED_FILES_FILE` after the command returns.

The helper currently buffers Git’s path output up to Node’s default 1 MiB limit. A larger list fails the run without invoking the wrapper or widening its scope; stream the list if a real project reaches this limit.
