---
name: delivery
description: "Run P8 delivery for a finished PROJ: probe merge conflicts against main in a throwaway worktree, render the PR body from state.json + findings.json, create the PR via gh, poll CI with a bounded fix loop, and reconcile Checkpoint 2 review comments. Use when: (1) documentation (7) is complete and committed on the PROJ branch, (2) CI turned red on an open PROJ PR and needs the bounded fix loop, (3) PR review comments came back and need the CP2 reconcile loop. Not for: implementing stories (use executing), QA (use qa), writing docs (use documentation), plan approval (use checkpoint)."
---

# Delivery — P8: Conflict Probe, PR, CI, Checkpoint 2

Owns the P8 phase (CONCEPT.md §4): the last autonomous phase before the
second human checkpoint. Everything human-facing here is rendered from
data — the PR body comes from `state.json` + `findings.json` via a
template script, never freehand. The human's job at CP2 is reviewing
and merging; this skill's job is making that reviewable.

## Codex Adaptation

This skill is aligned with the Claude variant. In Codex: use
`spawn_agent` roles (`worker` or default) for fix tasks named `micro-fixer` —
do not assume Claude's Agent tool, `subagent_type`, or
`run_in_background` exist. Reusable skill assets live under
`~/.codex/skills/...`.

## Input

- `specs/PROJ-<X>-<theme>/state.json` at `P7:done` (or `P8:*` when resuming)
- `specs/PROJ-<X>-<theme>/findings.json` — the ledger (debt section source)
- The PROJ branch `proj/PROJ-<X>` with all commits including docs
- `.worktree` metadata from P0: dependencies are isolated in the persistent
  PROJ worktree; `.env.local`, development database, hosted-auth limits, and
  any configured dev port remain deliberately shared as recorded

## Workflow

### 0. Gate + phase transition

`bash scripts/state.sh get <X> <theme> '.phase + ":" + .status'` must be
`P7:done` (or an interrupted `P8` state when resuming). Then:
`bash scripts/state.sh transition <X> <theme> P8 running`

### 1. Conflict probe against main

Run `bash scripts/conflict-probe.sh <X> <theme>` (throwaway worktree —
it never touches real branches) and read the JSON verdict:

- `none` → continue.
- `trivial` (lockfiles/generated only) → merge `main` into the PROJ
  branch, regenerate the trivial files (e.g. re-run the package
  manager), commit, re-run the probe. It must now report `none`.
- `semantic` → ONE bounded resolution attempt using
  `api-contracts.md`/architecture-delta as the reference. Resolved →
  commit + re-probe. Unresolved → record the affected files as a risk
  assessment in state (`.summary` addendum) so it renders into the PR
  body, and continue to PR creation — the human decides at CP2. A
  semantic conflict is a planning signal; note it for the retrospective.

### 2. Complete the ledger before rendering

1. `bash scripts/harvest-debt.sh <X> <theme>` — collect `ponytail:` markers
2. `node scripts/ledger.mjs auto-defer <X> <theme>` — open Medium/Low → debt (§8)
3. `node scripts/ledger.mjs stats <X> <theme>` — **open_blocking MUST be 0.**
   If not, P8 must not deliver: route back to the P6 fix loop; after
   three failed repairs on the same finding it is a stop condition.

### 3. Create the PR — body rendered, never freehand

<HARD-GATE>
1. Set the run summary in state (the ONE place free text enters):
   `bash scripts/state.sh set <X> <theme> .summary "<2–4 sentences: what was built, notable decisions, semantic-conflict risk note if any>"`
   Optionally record doc changes: `bash scripts/state.sh set <X> <theme> .docs_changed '["docs/ARCHITECTURE.md", …]'`
2. `git push -u origin proj/PROJ-<X>`
3. `node scripts/render-pr-body.mjs <X> <theme> > /tmp/pr-body.md`
4. `gh pr create --title "PROJ-<X>: <theme>" --body-file /tmp/pr-body.md --base main`
5. Record it: `bash scripts/state.sh set <X> <theme> .pr '{"number": <N>, "url": "<url>", "ci": "pending"}'`

Never write the PR description by hand and never edit the rendered body
— fix the data (state/ledger) and re-render instead. Mode B (Jira)
sync-back is Stage 3 — do not improvise ticket comments.
</HARD-GATE>

### 4. CI polling with a bounded fix loop

Run `bash scripts/ci-poll.sh <pr-number>`:

- Exit 0 (green) → `bash scripts/state.sh set <X> <theme> .pr.ci green`, continue.
- Exit 1 (red) → the script printed the failing checks and verbatim
  `--log-failed` output. Spawn a fix task named `micro-fixer` with EXACTLY that
  verbatim output + the affected file paths (no context pack — §5 spawn
  tiering), commit, push, re-poll. **Max 3 attempts**; the 4th red on
  the same check is a stop condition (§8).
- Exit 2 (timeout) → stop condition; record `.pr.ci timeout`.

### 5. Seal the autonomous part

The P8 seal changes the PR head, so the earlier green result no longer proves
the final commit. Transition, commit, and push the seal, then poll CI again:

```bash
bash scripts/state.sh set <X> <theme> .worktree.cleanup_status removed
bash scripts/state.sh set <X> <theme> .worktree.cleanup_reason \
  '"removed after final CI, upstream-head, and clean-tree verification"'
bash scripts/state.sh transition <X> <theme> P8 done
git add specs/PROJ-<X>-<theme>/state.json
git commit -m "chore(PROJ-<X>): seal P8 delivery"
git push
FINAL_CI_HEAD=$(git rev-parse HEAD)
bash scripts/ci-poll.sh <pr-number> 1800 "$FINAL_CI_HEAD"
[ "$(git rev-parse HEAD)" = "$FINAL_CI_HEAD" ]
[ "$(gh pr view <pr-number> --json headRefOid --jq .headRefOid)" = "$FINAL_CI_HEAD" ]
```

Only exit 0 from that final poll makes `P8:done` valid. A red/timeout reopens
delivery work; immediately run
`scripts/worktree.sh retain <X> <theme> "<exact final-CI reason>"` so the
preserved worktree records why cleanup was refused. Do not claim the previous
head's CI as evidence for this one.

After exit 0, capture the exact verified commit and remove the persistent
worktree only through the safety helper:

```bash
scripts/worktree.sh cleanup <X> <theme> --ci-verified-head "$FINAL_CI_HEAD"
```

The poll is bound to the pre-poll local/PR head and rechecks the PR head after
all workflows finish; the two explicit comparisons above also reject a local
or remote head change between poll and cleanup. The helper additionally
requires `.pr.ci == "green"`, `P8:done`, the sealed
`removed` intent, the expected branch/registration, an identical pushed
upstream commit, and a clean tree. It removes only the registered worktree
(including its reproducible ignored dependencies and managed env symlink) and
keeps the branch. On any failed predicate it changes the retained worktree to
`cleanup_status: "retained"` via `state.sh`, records the exact reason, moves a
sealed P8 to `P8:blocked`, and prints the safe P8-resume action. Resume P8 so it
reseals, pushes, and re-polls the new exact HEAD; a direct cleanup retry against
the now-dirty retained state is intentionally impossible. Never substitute
`git worktree remove --force` by hand.

When `SKILLCHAIN_RUNNER_MANAGED=1`, do not call cleanup in the writer lane.
The runner repeats the final CI poll after the lane exits and performs this
same guarded cleanup; this avoids deleting the runner's current filesystem
before it has verified the P8 seal.

The run is then waiting on the human. A runner-managed run emits the final PR,
CI-head, cleanup status/reason, and safe retry command (when retained) from the
sealed state/helper result; nothing further happens autonomously.

→ NEXT ACTION: human reviews and merges the PR (Checkpoint 2 — for
overnight runs, in the morning via the morning report). After the merge,
set this PROJ's `Status` to `shipped` in `specs/product-roadmap.md` if that
file exists — it is what tells `chain-guide` (0) that dependent PROJs are
unblocked.

### 6. Checkpoint 2 — reconcile PR review comments (when they arrive)

Apply the **checkpoint** (4a) reconcile loop to the PR comments, via
`gh pr view --comments` / `gh api`:

1. Classify each comment, point by point: **fix now** / **debt** /
   **reject with rationale**.
2. `fix now` → fix task named `micro-fixer` (comment verbatim + file paths),
   verify, commit.
3. `debt` → `ponytail:` marker + ledger record
   (`node scripts/ledger.mjs add <X> <theme>` with status `deferred`),
   reply on the comment with the finding id.
4. `reject` → reply on the PR with the rationale — never silently ignore.
5. Append the round to `specs/PROJ-<X>-<theme>/decisions.md`
   (decisions template frame), push, re-request review.
6. Principle-level feedback ("I never want to see this again") →
   AGENTS.md/GUIDELINES candidate through the existing approval
   pipeline (documentation skill owns the merge).

Repeat per review round until merge. `state.json` stays `P8:done`; the
merge itself transitions nothing — after merge, `done:done` may be set
for bookkeeping: `bash scripts/state.sh transition <X> <theme> done done`.

## Completion Checklist

- [ ] Conflict probe verdict handled (`none` reached, or semantic risk rendered into the PR)
- [ ] Debt harvested + Medium/Low auto-deferred; `open_blocking` = 0
- [ ] PR body rendered from data; no hand-written or hand-edited description
- [ ] PR created; `.pr` block in state.json
- [ ] CI green, or bounded fix loop / stop condition recorded truthfully
- [ ] state.json `P8:done`
- [ ] final CI verified the exact pushed seal commit
- [ ] PROJ worktree removed safely, or retained with exact state-backed reason and retry command
- [ ] CP2 comment rounds reconciled point by point with decision-log entries

## Git Commit Format

```text
chore(PROJ-<X>): P8 delivery — conflict probe, PR #<N>, CI green
fix(PROJ-<X>): CP2 round <NN> — <short summary of applied fixes>
```
