---
name: checkpoint
description: "Run a human checkpoint as a structured reconcile loop: present a compact review package, collect feedback point by point (adopt/change/reject/defer), write the decision log, cascade every change through all affected planning artifacts, and seal the result in state.json. Use when: (1) architecture + wave plans are ready for Checkpoint 1 approval before any execution, (2) PR review comments need reconciling at Checkpoint 2 (invoked via delivery), (3) intake bootstrap drafts need validation (via the intake skill, 0b). Not for: producing the plans themselves (use writing-plans), resolving PRD reviews on the discovery track (use review-reconcile), P0 setup (use setup)."
---

# Checkpoint — Structured Reconcile Loop For CP1, Bootstrap, CP2

Checkpoints are not a "looks good? yes/no" question. This skill
generalizes the proven `review-reconcile` (2c) pattern to the two human
checkpoints of the agent workflow (CONCEPT.md §4): feedback is collected
point by point, every point ends in an explicit decision, the decision
log is durable, and each change cascades through ALL affected artifacts
before anything is sealed. Between the checkpoints the run is
autonomous — this loop is where the human steers.

Three call sites, one loop:

| Call site | Reviewed | Seal |
|---|---|---|
| **CP1** (main) | architecture-delta + wave plans + gate config + api-contracts | `state.json` → `CP1:approved` — the ONLY thing that unlocks P0 |
| **Bootstrap** (via 0b_intake) | intake first drafts (all eight baseline files) | curated baseline commit — no state.json |
| **CP2** (via delivery, 8) | PR review comments | classified comments: fix now / debt / reject |

## Core Principle

Decide before you edit, record before you move on. Every review point
ends in exactly one of `adopt` / `change (how)` / `reject (why)` /
`defer` — recorded in the decision log BEFORE the next point is raised.
Never silently absorb feedback by editing an artifact with no recorded
rationale, and never seal an approval while a cascade is unapplied.

CP1 has one narrow exception: Step 0's fast path, which auto-adopts and seals
without an interactive prompt — but only when the upstream cross-reviews
already did the judging and came back clean. It is still a recorded decision
(one decision-log entry, same as any other), it is still conditional on the
machine validator, and anything that actually needed a human call still gets
the full loop. It removes a redundant re-confirmation, not the checkpoint
itself.

## Input

1. `specs/PROJ-<X>-<theme>/architecture-delta.md` (or `3-4_plan/PROJ-<X>-architecture.md`)
2. `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-<N>-plan.md` (all waves) + `wave-gate-config.json`
3. `specs/PROJ-<X>-<theme>/api-contracts.md` (if present)
4. Open pre-mortem risks / plan self-review findings (if present)
5. `specs/PROJ-<X>-<theme>/decisions.md` from earlier rounds (if present)

## Workflow (CP1 — the main application)

### 0. Fast path — auto-approve when upstream was already clean

Before presenting anything, check whether this round needs the interactive
walk-through at all. All four must hold, checked in this order (cheapest
first):

1. `specs/PROJ-<X>-<theme>/decisions.md` has no open or deferred entry from an
   earlier round. An earlier round that left something open is a standing
   decision this round must still honor or revisit — never silently paper
   over it. Fails → no fast path, continue at Step 1.
2. Both cross-reviews actually ran — `.cross_review[]` in state.json (appended
   by `cross-review.sh --persist`, never by hand) has at least one record with
   `mode == "architecture"` and at least one with `mode == "plan"`:
   ```bash
   bash ~/.claude/skills/4a_checkpoint/scripts/state.sh get <X> <theme> \
     '[.cross_review[]? | .mode] | (index("architecture") != null) and (index("plan") != null)'
   ```
   `false` (a mode never ran — declined, or run without `--persist`) → no fast
   path, continue at Step 1.
3. Nothing from those rounds is still open. This is the exact query
   `cross-review.sh` itself uses to decide BLOCKING — reuse it rather than
   inventing a second definition of "clean":
   ```bash
   jq '[.findings[]? | select(.status == "open") | select(.severity == "critical" or .severity == "high") | select(.source == "cross-review" or ((.sources // []) | index("cross-review")))] | length' \
     specs/PROJ-<X>-<theme>/findings.json 2>/dev/null || echo 0
   ```
   Nonzero (a finding needed a human decision and nobody resolved it in the
   ledger) → no fast path, continue at Step 1.
4. Run the machine consistency validator (exact command in Step 4 below). Any
   error → no fast path, continue at Step 1.

If all four hold: skip the interactive walk-through (Steps 1-2) and the
cascade (Step 4 — nothing changed, so there is nothing to cascade). Append one
decision-log entry to `decisions.md` (`templates/decisions.md.tmpl`):
Decision `adopt`, Detail "auto-approved — architecture and plan cross-review
both clean, validator green", Cascade `none`. Go straight to Step 5 (Seal the
approval) and tell the user in one line that CP1 auto-approved and why.

This is the only auto-approve path. Anything cross-review didn't clear, or
that a human already had to judge, or that an earlier round left open, always
gets the interactive loop below — that is precisely the case where a rubber
stamp is not safe. The fast path removes a redundant re-confirmation of
already-reviewed artifacts; it does not remove the one check that only fires
when something is actually wrong.

### 1. Present a compact review package — never raw artifacts

Build a summary the human can decide on in minutes:

- **Decision summary:** the NEW decisions of this PROJ (the delta),
  one line each — not the full architecture text.
- **Wave overview:** waves with story sets, dependency rationale, and
  execution mode per wave.
- **Open risks:** unresolved pre-mortem findings and weak spots the
  plan self-review flagged.

Point to the full artifacts by path for drill-down; do not paste them.

### 2. Collect feedback point by point

Walk the package one point at a time (AskUserQuestion or guided
conversation — never one bulk "any comments?" prompt). For each point:

1. Explain plainly what was decided/planned and why.
2. Frame realistic alternatives with a recommendation where feedback
   suggests a change.
3. Close with exactly one outcome: **adopt** / **change (how)** /
   **reject (why)** / **defer**.

### 3. Write the decision log

Append this round to `specs/PROJ-<X>-<theme>/decisions.md` using
`templates/decisions.md.tmpl` (copy the template frame; one `D-<X>-<NN>`
entry per point, IDs unique across rounds). The log is append-only —
earlier rounds are never edited. P7 curation later migrates decisions
with lasting value into `docs/ARCHITECTURE.md`/ADRs.

### 4. Cascade updates into ALL affected artifacts

<HARD-GATE>
One decision ("drop US-7, cut Wave 2 differently") touches several
artifacts. For every `change`/`reject` decision, update EVERY affected
file — architecture-delta, wave plans, `wave-gate-config.json`,
api-contracts — and record the touched files in the entry's
**Cascade** field. Then re-run the plan self-review (the consistency
check from writing-plans, 4): story/dependency/contract consistency
across all waves. A checkpoint that edits a wave plan but not the gate
config produces an overnight run that gates against a stale plan.

Run the machine consistency validator after every cascade and once more even
when the round adopted every point unchanged:

```bash
node ~/.claude/skills/4a_checkpoint/scripts/validate-wave-plan.mjs \
  specs/PROJ-<X>-<theme>/3-4_plan
```

This is a hard pre-approval gate. It checks unique AC IDs, their task/command
mapping, bidirectional task/test-file agreement, broad regressions, auth-budget
hooks, and protected-route coverage through auth state or mapped authenticated
E2E files. Do not seal CP1 while it is red. For a legacy layout, pass the
existing `6_plan/` directory instead.
</HARD-GATE>

### 5. Seal the approval

Only after the cascade is clean:

1. Read the `state.json` created with the PROJ folder by brainstorming (1).
   If this is a legacy PROJ without one, recover once with
   `bash ~/.claude/skills/4a_checkpoint/scripts/state.sh init <X> <theme>`;
   it must still be `CP1:pending` before this checkpoint approves it.
2. `bash scripts/state.sh transition <X> <theme> CP1 running` (first
   round only), then `bash scripts/state.sh transition <X> <theme> CP1 approved`
3. `bash scripts/state.sh set <X> <theme> .decision_log specs/PROJ-<X>-<theme>/decisions.md`
4. Commit: `docs(PROJ-<X>): CP1 approved — decision log + cascaded plan updates`

`CP1:approved` in state.json is the only thing that unlocks P0. Never
set it by hand, never set it while decisions are open or deferred
points are unresolved-but-blocking.

→ NEXT ACTION: run **setup** (4b) for P0, then execution.

## CP2 Variant (invoked by delivery, 8)

Same loop over PR review comments instead of plan artifacts: classify
each comment `fix now` (spawn fix, verify, push) / `debt` (ledger record
via `scripts/ledger.mjs`, `ponytail:` marker) / `reject with rationale`
(reply on the PR via `gh`). Decision log entries carry the PR comment
link. Principle-level feedback ("I never want to see this again") is
harvested as an AGENTS.md/GUIDELINES candidate through the existing
approval pipeline — not silently applied.

## Bootstrap Variant (via 0b_intake)

Validation of the intake first drafts with the same point-by-point
pattern. Generated docs are HYPOTHESES, not truth — the loop exists to
turn them into a baseline the developer actually stands behind.

- **Input:** the provenance-marked drafts in `specs/intake/` (all eight
  baseline files: PRODUCT, ARCHITECTURE, GUIDELINES, DESIGN-SYSTEM,
  components, security-baseline, test-conventions, root AGENTS.md).
- **Review queue:** every `[gap: ...]`, every `[assumed]`, every
  inconsistency the scan flagged — plus anything the developer wants to
  challenge in the `[extracted: ...]` statements.
- **Loop:** identical to CP1 — present point by point, each point ends
  in exactly one of adopt / change (how) / reject (why) / defer,
  recorded BEFORE the next point.
- **Decision log:** `specs/intake/decisions.md`, ids `D-BOOTSTRAP-<NN>`,
  same `templates/decisions.md.tmpl` frame (checkpoint name:
  `Bootstrap`).
- **Cascade:** every decision is applied to the affected draft(s) —
  a GUIDELINES ruling may also touch ARCHITECTURE or add a Known Debt
  note.
- **Seal:** a git COMMIT of the curated baseline (done by the intake
  skill after `intake-seal-check.sh` passes) — explicitly NO
  `state.sh init` and NO phase transition. The bootstrap is pre-PROJ:
  state.json is born at CP1 of the first PROJ.

## Completion Checklist

- [ ] Fast path checked first (Step 0); took it only if decisions.md was clean, `.cross_review[]` had both an `architecture` and a `plan` record, the findings ledger had zero open Critical/High from cross-review, and the validator passed
- [ ] Review package presented compactly (summary, waves, risks) — fast-path rounds skip this
- [ ] Every point closed as adopt / change / reject / defer — none skipped (or the single fast-path `adopt` entry)
- [ ] Decision log appended with one `D-<X>-<NN>` entry per point
- [ ] Every change cascaded through ALL affected artifacts; Cascade field filled
- [ ] Plan self-review re-run after cascades — consistent
- [ ] Plan consistency validator passes after the final cascade
- [ ] state.json sealed `CP1:approved` with `.decision_log` set (CP1 only)
- [ ] Committed

## Git Commit Format

```text
docs(PROJ-<X>): CP1 approved — decision log + cascaded plan updates
```

## Legacy Folder Layout

PROJ folders created before the layout rename use different subfolder
names. Mapping, old → current:

`2_visual-companion/` → `1b_visual-companion/` · `4_design/` → `1c_design/` ·
`5_mockups/` → `1d_mockups/` · `3_PRDs/` → `2_PRDs/` ·
`8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` ·
`7_progress/` → `5_progress/`

If an expected folder is missing but its legacy twin exists, **read from the
legacy one and keep writing where the existing files already are**. Never
create a second folder next to it — a split PROJ is worse than an old name.
Say it once, then continue either way:

> "This PROJ uses the old folder layout (`<old>`). Rename the folders to the
> current names, or continue with the existing layout?"

Renaming is a `git mv` per folder plus a search for the old paths in the
PROJ's own documents. It is never a precondition for this skill.
