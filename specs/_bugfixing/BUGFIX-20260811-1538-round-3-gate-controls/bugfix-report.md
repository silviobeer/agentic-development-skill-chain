# BUGFIX — Round 3 gate controls

## Status

`fixed`

## Intake

- Reported symptom: A chained AC command can hide an empty second runner, configured auth hooks are not exercised before P0 seals, and runtime legacy AC strings silently bypass structured protections.
- User impact: A gate can report green without proving every runner or the configured failure path actually worked.
- Expected behavior: One runner per gate command, a safe P0 auth negative control through the configured hooks, and a loud migration stop for legacy strings.
- Actual behavior: Selection reads the first match, P0 accepts an unobserved hook, and `wave-gate.sh` assigns `legacy-N` metadata to string entries.
- Environment: Bash/Node framework scripts, Claude and Codex skill copies, 2026-08-11.
- Starting commit: `b25cddd831f0d9e7ca730cfaf7d75e3cc1f07727`
- Related issue/PROJ: Logofuchs PROJ-2 Round 3 handoff.

## Reproduction

- Outcome: `reproduced`
- Steps or command: `bash scripts/test-wave-plan-validator.sh`; `bash scripts/test-wave-gate.sh` after adding the three controls.
- Browser/client and state: Deterministic shell fixtures; no hosted identities consumed.
- Evidence: The validator accepts `npm test && npx playwright test`; the gate accepts string ACs as `legacy-N`; no auth negative-control mode exists.
- Positive control: Existing structured single-runner configs and normal auth preflight remain green.

## Diagnosis

- Trigger: Shell-chained test runners, a mistyped/unexercised project hook, or an old string-form config reaches P0/P5.
- Code cause: The contract permits ambiguous command composition, setup has only a generic negative-control instruction, and the runtime retains a legacy compatibility branch.
- Confidence and evidence: High; each branch is directly visible in the validator, setup instructions, and wave gate.
- Affected boundary: Wave-plan validation, P0 setup, and wave-gate runtime.

## Why Tests Missed It

- Primary escape category: `weak-oracle`
- Contributing escape categories: `missing-coverage`, `not-selected`
- Existing tests inspected: Wave-plan validator and both platform wave-gate behavior harnesses.
- Evidence: They cover zero total selection and auth exhaustion, but not a second runner, configured-hook control mode, or runtime legacy rejection.
- Guard being added or repaired: Three deterministic Red→Green controls in the existing harnesses.

## Fix Plan

- Minimal change: Reject shell-chained gate commands and legacy strings; add one safe gate mode that makes the configured auth hooks expose their negative-control branch.
- Files/boundaries: Shared validator copies, both wave-gate variants, writing/setup/executing guidance, existing harnesses.
- Regression-test layer and location: `scripts/test-wave-plan-validator.sh`, `scripts/test-wave-gate.sh`.
- Acceptance checks and exact commands: Both harnesses, `./scripts/validate.sh`, installed/source parity.
- Non-goals: Draining a real hosted bucket, migrating application configs automatically, or addressing the separate CodeRabbit findings.
- Compatibility/rollback concern: Legacy and chained configs now stop with migration guidance; auth projects must make their hooks honor the documented negative-control environment flag.

## Red Proof

- Command: `bash scripts/test-wave-plan-validator.sh`; `bash scripts/test-wave-gate.sh`.
- Selected tests: One chained command, one runtime legacy string, and one configured auth-hook negative control.
- Expected bug-specific failure: Observed before production changes: `expected validator failure containing: must invoke exactly one test runner`; `FAIL: codex/legacy-ac: expected failure`; `FAIL: codex/auth-negative-control: got rc=1, expected 75`.

## Implementation

- Changed behavior: AC and regression entries reject shell chaining; validator and runtime reject legacy AC strings with migration fields; the gate has an auth-budget negative-control mode that exercises configured hooks under the shared lock and persists `infrastructure_failed` with retained logs.
- Changed files: Six aligned validator copies, both platform wave gates, planning/setup/executing guidance, and the two existing behavioral harnesses.
- Implementer/fix attempts: One narrow micro-fixer implemented the AC validator guard; the orchestrator extended the same root-cause guard to regressions and integrated the independent runtime/P0 fixes. Attempt 1 is green in targeted tests.

## Verification

- Regression test green: `wave-plan validator tests passed`; `wave-gate behavior tests (codex + claude): PASS`.
- Relevant suite: Both focused harnesses pass after observing their bug-specific Red controls; the inactive auth-hook positive control exits 73 with a specific error.
- Full suite: `./scripts/validate.sh` → `validate: ok`, including all 37 worktree behavior groups.
- Lint/typecheck/build: `bash -n`, `node --check`, six-way validator byte comparison, and `git diff --check` pass.
- Original path re-tested: Chained AC and regression commands are rejected; string ACs stop in the validator and runtime with the required fields; the P0 mode invokes both configured hooks under the shared lock, retains their output, exits 75, and persists `infrastructure_failed`.
- CodeRabbit: Skipped; this repository has no `.coderabbit.yaml`/`.coderabbit.yml` configuration.
- Sonar: Skipped; this repository has no `sonar-project.properties` or configured project entry point.

## Prevention And Remaining Risk

- Why this should not recur unnoticed: The controls assert rejection text, exact infrastructure codes, persisted classification, shared-lock invocations, and retained evidence instead of trusting clean command exits.
- Remaining risks or skipped checks: Existing target configs need deliberate migration; auth hooks must implement the documented environment-controlled simulation. No hosted bucket was drained, by design.
- Proposed AGENTS.md candidate, if any: None.
