# BUGFIX — Keep PROJ worktree until PR merge

## Status

`fixed`

## Intake

- Reported symptom: P8 removes the persistent PROJ worktree as soon as the PR's final CI is green.
- User impact: Review follow-up and bug fixes cannot continue in the prepared worktree while the PR is still open.
- Expected behavior: Keep the worktree while the PR is open; remove it only after the PR is merged.
- Actual behavior: The runner calls guarded cleanup immediately after final PR CI, and the helper has no merge-state predicate.
- Environment: Local repository scripts at the starting commit below.
- Starting commit: `be8aaea6f8885f10106305b043e9eeae1c89ff4d`
- Related issue/PROJ: Standalone framework bug.

## Reproduction

- Outcome: `reproduced`
- Steps or command: Advance a fixture to `P8:done`, leave PR state `OPEN`, then call `worktree.sh cleanup` with the verified head.
- Browser/client and state: Shell/Git fixture; PR state is supplied by a deterministic `gh` stub.
- Evidence: Before the fix, `bash scripts/test-worktree.sh` failed with `FAIL: cleanup removed an unmerged PR worktree`.
- Positive control: The existing successful-cleanup fixture proves removal still works when all prior predicates pass.

## Diagnosis

- Trigger: Final CI turns green before the PR is merged.
- Code cause: `worktree.sh cleanup` has no authoritative PR merge check, and `runner/run-phase.sh` invokes it directly after final CI.
- Confidence and evidence: High; all cleanup callers route through the helper, while the runner's `finalize_p8_cleanup` calls it immediately after head checks.
- Affected boundary: Persistent worktree cleanup in P8 delivery.

## Why Tests Missed It

- Primary escape category: `missing-coverage`
- Contributing escape categories: None.
- Existing tests inspected: `scripts/test-worktree.sh` successful cleanup and post-seal resume cases.
- Evidence: Existing fixtures model final green CI but never distinguish an open PR from a merged PR.
- Guard being added or repaired: A deterministic open-PR retention test plus a merged-PR removal positive control.

## Fix Plan

- Minimal change: Require authoritative `MERGED` PR state at the shared cleanup helper; make the runner treat an open PR as a successful waiting state; align Codex/Claude delivery instructions.
- Files/boundaries: `worktree.sh` synchronized copies, `runner/run-phase.sh`, delivery skill copies, `scripts/test-worktree.sh`.
- Regression-test layer and location: Shell behavior test in `scripts/test-worktree.sh`.
- Acceptance checks and exact commands: `bash scripts/test-worktree.sh`; `./scripts/validate.sh`.
- Non-goals: Polling indefinitely for a merge, deleting the PROJ branch, or changing review-comment handling.
- Compatibility/rollback concern: Cleanup now requires authenticated `gh pr view`; P8 already requires `gh` for PR and CI operations.

## Red Proof

- Command: `bash scripts/test-worktree.sh`
- Selected tests: One new open-PR cleanup behavior group.
- Expected bug-specific failure: Cleanup succeeds and removes the worktree even though the stub reports `OPEN`.

## Implementation

- Changed behavior: Cleanup now queries the authoritative PR state. `OPEN` exits as a successful runner waiting state without changing `P8:done`; `MERGED` permits guarded removal; unavailable or unexpected PR states retain/block with an exact reason.
- Changed files: Four synchronized `worktree.sh` copies, `runner/run-phase.sh`, both delivery `SKILL.md` copies, and `scripts/test-worktree.sh`.
- Implementer/fix attempts: One `micro-fixer` attempt; independently reverified by the orchestrator.

## Verification

- Regression test green: `bash scripts/test-worktree.sh` → `PASS: 38 worktree behavior groups`.
- Relevant suite: The open-PR fixture retains the worktree at `P8:done`; the same runner fixture removes it on a later `MERGED` rerun.
- Full suite: `./scripts/validate.sh` → `validate: ok`.
- Lint/typecheck/build: `bash -n` on changed shell files, helper-copy `cmp`, and `git diff --check` all passed; the full validator also passed.
- Original path re-tested: Yes; the runner waits after green CI while the PR is open, then performs guarded cleanup after merge.
- CodeRabbit: Skipped; CLI is installed but the repository has no `.coderabbit.yaml`/`.coderabbit.yml` configuration.
- Sonar: Skipped; no `sonar-project.properties`, and `sonar-scanner` is unavailable.

## Prevention And Remaining Risk

- Why this should not recur unnoticed: Deterministic helper and runner tests cover both `OPEN` retention and later `MERGED` removal.
- Remaining risks or skipped checks: Post-merge cleanup requires an explicit P8/`auto` rerun; indefinite merge polling was intentionally not added.
- Proposed AGENTS.md candidate, if any: None.
