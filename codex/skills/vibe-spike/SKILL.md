---
name: vibe-spike
description: "Run a freeform exploratory coding session (a spike) on a scratch branch, keep a live journal of what gets tried and why direction changes as it happens, then distill that journal plus the resulting diff into a chain-ready concept seed once the session wraps up. Use when the user wants to vibe-code, prototype freely, or explore an idea in code before committing to a concept: going back and forth, trying dead ends, changing direction mid-session. Has three entry points: start a spike (scratch branch + live journal), resume a spike (re-load the journal and pick live documentation back up after a session break), and wrap up a spike (distill journal + diff into specs/_vibe-spike/.../chain-input.md, then ask what to do with the branch). Not part of the 0-8 chain; its chain-input.md feeds 1_brainstorming as raw input, not a replacement for it. Not for planned feature work, TDD implementation, or bug fixes — use writing-plans/executing or bugfixing instead."
---

# Vibe Spike

Bridge freeform exploratory coding back into the chain. A spike is allowed to
be messy — dead ends, pivots, half-finished experiments — because its code is
never meant to ship. What must survive the session is the *essence*: what was
learned, what worked, what didn't, and what question is now sharper than
before. This skill captures that essence live, while it happens, so nothing
gets lost when the spike branch is eventually thrown away.

This is an optional workflow outside the numbered 0-to-8 feature chain. It
does not create a PROJ, PRD, architecture document, or wave plan. Its output
is raw input for `1_brainstorming`, not a replacement for the concept work
brainstorming does.

## Working Modes

### Start a spike

Use this mode when the user wants to begin exploring an idea in code.

1. Ask one short question if not already clear: what idea or problem is being
   explored? One or two sentences is enough — this is not a requirements
   interview.
2. Confirm the branch. If the user is already on a fresh scratch branch, reuse
   it. Otherwise propose `spike/<slug>` off the current base branch and create
   it after confirmation — branch creation is cheap and reversible, but still
   ask rather than assume.
3. Create the run folder and seed the journal:

   ```text
   specs/_vibe-spike/VIBE-YYYYMMDD-HHMM-<slug>/
   └── journal.md
   ```

   Seed `journal.md` with the spike question, the start commit
   (`git rev-parse HEAD`), the base branch, and the start timestamp.
4. Tell the user the journal is live and that entries will be appended
   automatically at pivots — they don't need to ask for it.

### Resume a spike

Live documentation only holds while this skill's instructions stay loaded in
the active conversation. A new session, a compacted context, or a plain
"let's keep going with the spike" after a break means that duty was dropped
and must be picked back up explicitly — never assume silent continuity.

Use this mode whenever the user wants to continue a spike that isn't backed
by an unbroken live-documented session: starting a new chat on a `spike/*`
branch, saying "resume the spike", or pointing at an existing run folder.

1. Find the run folder. If the current branch matches a `journal.md`'s
   recorded branch, use it. Otherwise list `specs/_vibe-spike/VIBE-*/` and ask
   which one, or offer to start a new spike if none fits.
2. Read the full `journal.md` to reconstruct context — question, prior
   entries, last recorded state.
3. Compare the journal's last entry against `git log <base>..HEAD --oneline`.
   If commits exist beyond the last entry (work done while this skill wasn't
   watching), do not silently treat that gap as covered:
   - Best-effort reconstruct it from `git log`/`git diff` into one entry,
     and explicitly label it `(reconstructed from git — not live-captured)`
     so wrap-up can weigh it as lower-fidelity than a real-time entry.
   - Ask the user for the missing intent/reasoning only if the commits look
     ambiguous enough that a wrong guess would mislead the eventual
     `chain-input.md`.
4. Append a resume marker entry (timestamp, "resumed after a session break")
   so the timeline stays honest about the gap.
5. Confirm to the user that live documentation duty is back on, then continue
   in "During the spike" mode below for the rest of the session.

### During the spike (live documentation)

This is the core of the skill and runs continuously through the session
(after either Start or Resume), not just at the start or the end.

After each meaningful pivot, experiment, or decision — not after every
trivial edit — append a short, timestamped entry to `journal.md`:

- what was tried;
- the outcome (worked / didn't / partial);
- why it was kept or discarded;
- the new question or direction that followed, if any.

Keep entries short and chronological. They are raw material for the wrap-up
distillation, not documentation — write for later, not for polish. Do not
clean up code, add tests, or worry about quality during the spike itself;
holding that bar defeats the point of a spike. If the user pivots hard enough
that earlier experiments become irrelevant, still keep their journal entries
— an abandoned direction is evidence too.

### Wrap up a spike

Use this mode when the user says they're done exploring, want to wrap up, or
want to distill the spike into something usable.

1. Read the full `journal.md` — it is the primary source.
2. Read `git log <base>..HEAD --oneline` and
   `git diff <base>...HEAD --stat` as corroborating evidence only, to fill
   gaps the journal didn't capture. Do not re-derive the essence from the diff
   alone; a vibe-coding diff without the journal's reasoning is misleading.
3. Ask clarifying questions only where the journal leaves the essence
   ambiguous. Do not re-interview what is already documented.
4. Write `chain-input.md` (template below) into the same run folder.
5. Ask explicitly what should happen to the branch: keep it as reference,
   delete it now, or decide after brainstorming. Do not assume or act without
   an answer — the branch may hold context worth returning to.
6. Report: the run folder path, a one-line essence, the recommended next
   skill (`1_brainstorming`), and the recorded branch decision.

## Output Location

```text
specs/_vibe-spike/VIBE-YYYYMMDD-HHMM-<slug>/
├── journal.md        # written live during the spike
└── chain-input.md    # written at wrap-up
```

## journal.md Shape

```markdown
# Spike Journal — VIBE-YYYYMMDD-HHMM-<slug>

**Question:** <what we're exploring>
**Base branch:** <branch>
**Start commit:** <sha>
**Started:** <timestamp>

## Entries

### <timestamp> — <short label>
- Tried: <what>
- Outcome: <worked | didn't | partial>
- Kept/discarded because: <why>
- Follow-up question: <if any>
```

## chain-input.md Template

Keep this short enough to paste directly into brainstorming's feature-seed
intake.

```markdown
# Chain Input — VIBE-YYYYMMDD-HHMM-<slug>

## Recommended Next Action
Feed this into `1_brainstorming` as the feature seed. This is raw input, not
an approved concept — brainstorming still owns scope, alternatives, and
assumption playback.

## What Was Explored
<the original question or hypothesis>

## Essence
<2-5 sentences: what actually matters, distilled from the back-and-forth>

## What Worked
- <finding, with a journal entry or file pointer as evidence>

## What Didn't (and why it's worth knowing)
- <dead end, with the reason it was dropped — often as valuable as a hit>

## Open Questions For Brainstorming
- <question the spike raised but did not answer>

## Rough Story Seeds (tentative, unvalidated)
- <possible user-story direction, explicitly flagged as not yet validated>

## Evidence
- `journal.md`
- `git diff <base>...<spike-branch>` (<N> files changed)

## Branch Disposition
<kept as reference at <branch> | deleted | pending brainstorming outcome>
```

## Hard Rules

- Never delete or overwrite the spike branch without an explicit answer from
  the user at wrap-up.
- Do not edit application code during wrap-up; wrap-up only reads the branch
  and writes into `specs/_vibe-spike/`.
- Do not create a PROJ, PRD, or architecture doc from this skill directly.
- `chain-input.md` must stay concise — if it grows past what fits in a
  brainstorming intake message, cut detail rather than let it become a second
  concept document.
- Never treat a session gap as fully documented. If commits exist that no
  live entry covers, reconstruct and label them at resume time rather than
  presenting the journal as complete.

## Final Response

Keep it short:

- Run folder path.
- One-line essence.
- Recommended next skill: `1_brainstorming`.
- Branch decision recorded.
