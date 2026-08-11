# BUGFIX — Gate cost and evidence integrity

## Status

`fixed`

## Intake

- Reported symptom: Browser ACs hide hosted-auth rate limits, wave plans cannot place expensive checks outside the wave, and cross-review embeds an unbounded full PROJ diff.
- User impact: Environmental exhaustion looks like product failure, waves spend hosted identities on broad regressions, and blocking reviews cannot fit provider input limits.
- Expected behavior: Current-wave behavior is proved immediately; broad hosted checks run in CI/nightly; environmental failures and scoped review omissions are explicit evidence.
- Actual behavior: All ACs run alike, the rate-limit guard reads only the AC stream, and `--diff-base` embeds every changed path.
- Environment: Bash/Node framework scripts, installed Claude and Codex skills, 2026-08-11.
- Starting commit: `b25cddd831f0d9e7ca730cfaf7d75e3cc1f07727`
- Related issue/PROJ: Logofuchs PROJ-2 supplemental handoff.

## Reproduction

- Outcome: `reproduced`
- Steps or command: `bash scripts/test-wave-gate.sh`; `bash scripts/test-cross-review.sh`; `bash scripts/test-wave-plan-validator.sh` after adding the negative controls.
- Browser/client and state: Simulated Playwright assertion output with the provider 429 present only in a separate server-evidence stream.
- Evidence: Existing `provider_rate_limited` accepts one file; existing cross-review appends `git diff BASE..HEAD` whole; the validator has only `auth_consuming` and no phase placement.
- Positive control: Existing direct provider-signature retry and ordinary non-provider failure cases remain in `scripts/test-wave-gate.sh`.

## Diagnosis

- Trigger: A hosted-auth browser test fails after the provider bucket empties; a large PROJ reaches QA/P7; broad auth/browser suites are copied into per-wave commands.
- Code cause: Evidence is read from the wrong stream, diff scope is unbounded, and planning metadata cannot distinguish targeted wave proof from deferred broad coverage.
- Confidence and evidence: High; confirmed against installed and repository copies plus the measured 2.22 MB Logofuchs PROJ diff.
- Affected boundary: Wave gate, wave-plan validator/policy, QA/docs cross-review commands.

## Why Tests Missed It

- Primary escape category: `wrong-layer`
- Contributing escape categories: `missing-coverage`, `weak-oracle`
- Existing tests inspected: Wave-gate provider signature, auth preflight, plan validator, and cross-review adapter behavior.
- Evidence: The existing retry control places the signature in the AC log; no control separates browser output from server evidence. Cross-review had no diff-scope harness.
- Guard being added or repaired: Secondary rate-limit evidence hook, phase-policy validation, scoped-diff budget harness.

## Fix Plan

- Minimal change: Reuse `auth_consuming`; require reasons for hosted wave exceptions; declare broader quality/nightly commands separately; add a provider-neutral failure-evidence hook; scope diffs explicitly under a hard default budget.
- Files/boundaries: Wave gate, plan validator, planning/executing/QA/docs/cross-review guidance, deterministic shell harnesses, installed Claude copies.
- Regression-test layer and location: `scripts/test-wave-gate.sh`, `scripts/test-wave-plan-validator.sh`, `scripts/test-cross-review.sh`.
- Acceptance checks and exact commands: The three harnesses above, installed/source byte comparisons, `./scripts/validate.sh`.
- Non-goals: Refactoring the target application's Playwright auth setup or editing its live worktrees.
- Compatibility/rollback concern: Legacy runtime wave entries remain readable; newly validated plans become stricter and must classify deferred hosted checks.

## Red Proof

- Command: `bash scripts/test-wave-gate.sh`; `bash scripts/test-wave-plan-validator.sh`; `bash scripts/test-cross-review.sh`.
- Selected tests: One simulated browser/provider retry, two plan-policy cases, and scoped/unscoped diff controls.
- Expected bug-specific failure: Observed before implementation: browser evidence was ignored (`AC AC-1 failed rc=1`); the validator reported `expected validator failure` because it accepted the hosted wave command; cross-review rejected `--diff-paths` as unknown.

## Implementation

- Changed behavior: Failed auth-consuming ACs may consult retained secondary provider evidence and visibly pause/retry; wave auth now requires an explicit reason, broad checks declare `quality|ci|nightly` placement, and CI/nightly workflow wiring is inspected; cross-review scopes diffs explicitly, names omissions, and enforces a 900,000-byte default material ceiling.
- Changed files: Aligned Codex/Claude copies of `4_writing-plans`, `5_executing`, `6_qa`, `7_documentation`, and `cross-review`; validator copies; three harnesses; repository documentation.
- Implementer/fix attempts: One narrow micro-fixer for the rate-limit hook; one implementation attempt. Local implementation for independent policy/scope fixes; one implementation attempt each.

## Verification

- Regression test green: `wave-gate behavior tests (codex + claude): PASS`; `wave-plan validator tests passed`; `cross-review diff-scope tests passed`.
- Relevant suite: All three focused harnesses pass together; example JSON parses; byte-identical helper comparisons pass.
- Full suite: `./scripts/validate.sh` → `validate: ok`.
- Installed copies: `./scripts/install-claude.sh` and `./scripts/install-codex.sh` completed successfully; every repository skill directory matches its installed counterpart byte-for-byte.
- Lint/typecheck/build: `git diff --check`, Bash syntax checks, Node syntax checks, schemas, and all repository behavioral harnesses pass through `validate.sh`.
- Original path re-tested: The split-stream negative control now retains `ralph-wave-1-ac-1-attempt-1-rate-limit-evidence.log`, prints the pause, waits at least one second, retries, and passes on attempt 2. The real PROJ-2 QA input measures 874,675 scoped bytes under the 900,000-byte default instead of embedding its 2.22 MB full diff.
- CodeRabbit: Skipped; CLI exists but this repository has no `.coderabbit.yaml`/`.coderabbit.yml` configuration.
- Sonar: Skipped; both CLIs exist but this repository has no `sonar-project.properties` or configured project entry point.

## Prevention And Remaining Risk

- Why this should not recur unnoticed: The controls assert behavior and evidence, not only exit codes. Planning rejects unreasoned hosted work and reads the named workflow command. Review scope and omissions are included in the provider prompt and operator failure.
- Remaining risks or skipped checks: A real hosted bucket was not deliberately drained; the deterministic negative control simulates the exact split-stream evidence shape without consuming shared identities. Target repositories must supply a project-specific `rate_limit_evidence_cmd` and migrate legacy plan entries before strict validation.
- Proposed AGENTS.md candidate, if any: None; repository rules already require behavioral validation and synchronized helper copies.
