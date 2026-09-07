# BUGFIX — Wave gate repeated work and nested browser lock

This report records the original lock/performance investigation and its verification at commit `491091f`; its open-finding and wave-status statements are historical, not the current PROJ status. Later gate parallelism, helper synchronization and PROJ-level optimizations are documented in `docs/executing-skill.md` and `docs/installation.md`.

## Status

`partially verified`

## Intake

- Reported symptom: Wave 1 takes several minutes; user requested optimization after inspecting PROJ-49.
- User impact: browser verification stalls before opening the browser and retries repeat successful work.
- Expected behavior: run wave-specific proof once per equivalent command, preserve every AC result, and serialize database/browser access without nested acquisition.
- Actual behavior: twelve filtered AC launches, overlapping full-file regression, then a browser process waiting on its own enclosing lock.
- Environment: Linux, Bash/flock, Node node:test, Vitest, agent-browser; approved remote Supabase test project.
- Starting commit: framework `27e23ee6d1ccceabbc0d2d8bd9a2bde80cd3e841`; project `fbac32d6552fe16855274899b2ce2994fefaab5f`.
- Related issue/PROJ: `/home/silvio/projects/raumbuchv6-proj49/specs/PROJ-49-vorlagen-bibliothek`.

## Reproduction

- Outcome: twelve AC commands passed first attempt in about 70 seconds; overlapping 152-test regression took 35.10 seconds; browser timed out at 300 seconds and its retry spent an observed 275 seconds waiting on an inner flock.
- Steps or command: gate-owned shared lock → `PROJ49_WAVE=1 node --test tests/e2e/proj49-template-flows.test.mjs` → initial SQL helper → second lock acquisition.
- Browser/client and state: existing authenticated browser state, wave-1 activation scenario only; stall preceded browser launch.
- Evidence: live `/proc` descriptors showed the enclosing lock on fd 8, but a pipe on fd 8 in the node --test worker.
- Positive control: direct `node` execution preserves the inherited descriptor while still running node:test cases.

## Diagnosis

- Trigger: node --test creates a child with different descriptor ownership.
- Code cause: descriptor-based ownership detection in the child falsely reports no enclosing lock; AC cache also keys equivalent work by AC ID and regression reruns already-covered story files.
- Confidence and evidence: observed lock wait and descriptor mismatch; inspected current-wave command and route selections.
- Affected boundary: project browser entry point/configuration plus framework gate execution and planning guidance.

## Why Tests Missed It

- Primary escape category: `wrong-layer`; checks did not exercise the enclosing gate lock through the actual node --test child-process boundary.
- Contributing escape categories: `missing-test` for equivalent AC work across IDs and retry reuse; duplicated gate invocation in instructions.
- Existing tests inspected: wave-gate shell controls, wave-plan validator fixtures, PROJ-49 browser entry point.
- Guard being added or repaired: isolated lock-ownership checks, command-sharing/retry controls, cache-policy validation, preserved per-AC evidence.

## Fix Plan

- Minimal change: reuse equivalent AC execution; opt in only deterministic non-auth local regression reuse; keep build/review live; remove redundant smoke when current-wave E2E proves the route; execute the descriptor-aware browser entry point directly.
- Files/boundaries: aligned Codex/Claude gate scripts and skill instructions, six validator copies, shell controls; project browser entry point, gate config and wave-1 source plan.
- Regression-test layer and location: `scripts/test-wave-gate.sh`, `scripts/test-wave-plan-validator.sh`; project `scripts/tests/proj49-browser-lock.test.mjs`.
- Acceptance checks and exact commands: `bash scripts/test-wave-gate.sh`; `bash scripts/test-wave-plan-validator.sh`; `./scripts/validate.sh`; project `node scripts/tests/proj49-browser-lock.test.mjs` and real wave-1 browser/gate verification.
- Non-goals: remove ACs, widen browser scenarios, cache external/auth state, skip build/review, modify generated handoff runs.
- Compatibility/rollback concern: reuse is invalidated by HEAD/config changes; dependency/runtime/environment changes require clearing cached Ralph evidence. Project batching requires the updated gate to gain the execution reduction.

## Red Proof

- Framework command: pre-edit `bash scripts/test-wave-gate.sh` failed with `FAIL: codex/identical-ac-command: identical AC command executed twice`.
- Additional baseline controls against `git show HEAD:codex/skills/5_executing/scripts/wave-gate.sh` failed with `FAIL codex/regression-reuse: deterministic regression repeated` and `FAIL codex/browser-snapshot-timeout: expected failure` (old snapshot ran 3 seconds and succeeded; the new one-second bound fails it).
- Project command: pre-edit `node scripts/tests/proj49-browser-lock.test.mjs` raised `AssertionError: node --test must reject lost lock ownership instead of deadlocking` with actual exit `124`. After the fix, the check passed standalone/inherited serialization and prompt rejection of node --test.
- Expected bug-specific failure: equivalent AC command executes repeatedly; unchanged deterministic regression reruns; node --test child loses the lock descriptor.

## Implementation

- Changed behavior: twelve wave-1 AC IDs map to three full-file story commands; the four shared unit files remain a separate regression and only that deterministic regression opts into reuse. Browser regression keeps the wave-1 scenario; settings smoke uses its coverage and Autoklav detail smoke remains.
- Changed files: framework gate/validator scripts and execution/planning instructions, associated controls; project gate configuration, wave-1 plan, browser entry point and lock check.
- Implementer/fix attempts: separate bounded workers for framework execution, project locking, and scope/documentation.
- Delivery: project changes committed as `491091f`. Twelve changed installed skill files were synchronized to both `~/.codex/skills` and `~/.claude/skills` after verifying no baseline drift; resulting copies were verified byte-identical.

## Verification

- Regression test green: `bash scripts/test-wave-gate.sh` returned `wave-gate behavior tests (codex + claude): PASS`; validator controls passed, including valid/nonboolean/auth-consuming cache flags and AC-backed route coverage.
- Relevant suite: project plan consistency passed for all 10 waves and 193 ACs; project `node scripts/tests/proj49-browser-lock.test.mjs` passed independently.
- Full framework suite: `./scripts/validate.sh` passed with exit 0 and `validate: ok`; log: `/tmp/wave-gate-integration-58_bbrp5/framework-validation.log`.
- Lint/typecheck/build: targeted ESLint passed for changed project MJS files; diff whitespace checks passed in both repositories.
- Full project gate: exited 1 at the browser regression from commit `491091f`; log `/tmp/wave-gate-integration-58_bbrp5/project-gate.log`. Browser duration was 36.3 seconds, ending at the separate 30-second `Vakuumsystem` wait timeout. Durable evidence: project `5_progress/ralph-wave-1-regression-2.log`. Build, review, and smoke phases were not reached.
- Measured optimization: AC phase took about 42 seconds (previously about 70); all 12 AC IDs passed at current HEAD using three unique command logs (9 + 4 + 4 = 17 tests). Shared local regression ran 135 tests in 1.71 seconds (previous overlapping 152-test regression: 35.10 seconds). Together, 17 story tests + 135 shared tests preserve all 152 tests without replaying the story suites.
- Finding disposition: repaired lock `F-PROJ-49-052` is fixed through the ledger with commit `491091f`; separate flow failure `F-PROJ-49-053` remains open. The original 300-second deadlock is eliminated; framework optimizations are verified, but the whole wave is not green.
- Original path re-tested: the live wave-1 browser run passed lock acquisition and reached creation, then failed after 41.3 seconds waiting for `Vakuumsystem`. Auth preflight returned 200; failure was `agent-browser --session proj49-wave-1 wait --text Vakuumsystem`, `Wait timed out after 30000ms`, after the wizard create click. Command: `timeout --kill-after=5s 300s scripts/worktree.sh with-shared-lock -- bash -c 'node scripts/proj49-auth-state.mjs && node scripts/proj49-auth-budget.mjs && PROJ49_WAVE=1 node tests/e2e/proj49-template-flows.test.mjs'`; evidence: project `5_progress/wave-1-browser-lock-verification.log`. This is a separate flow/assertion issue; the real wave gate is not green.
- CodeRabbit: framework has no configured review command; skipped for this framework fix.
- Sonar: framework has no configured Sonar command; skipped.

## Prevention And Remaining Risk

- Why this should not recur unnoticed: runnable controls cover child lock ownership, shared AC execution, conservative cache invalidation, and protected-route coverage mapping.
- Remaining risks or skipped checks: external database/browser commands remain live; their elapsed time depends on external services. The live gate now exposes separate open flow finding `F-PROJ-49-053` (`Vakuumsystem`); full gate success remains blocked by that issue. Build/review/smoke have not been verified by this run.
- Proposed AGENTS.md candidate: none; execution guidance contains the workflow-specific rule.
