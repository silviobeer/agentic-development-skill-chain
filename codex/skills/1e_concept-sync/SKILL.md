---
name: concept-sync
description: "Reconcile mockup iteration changes back into the concept before requirements. Use after ui-mockup when stakeholders have iterated on the mockups (changes prompted directly into the HTML) and the agreed result must flow back into the concept. Reads the mockup iteration log, updates the concept doc, marks abandoned decisions, and signals handoff-ready for requirements-engineer. Primary step of the Product Discovery track, but also usable in the full 0-to-7 chain."
---

# Concept Sync — Reconcile Mockup Iterations Into The Concept

During mockup review, stakeholders iterate by prompting changes directly into the HTML mockups until everyone agrees. Those agreed changes drift away from the original concept. This skill closes that loop: it reads the tracked changes and updates the concept so the concept again reflects what was actually decided — before requirements are written.

This is the bridge between visual iteration and `requirements-engineer`. It is the primary reconciliation step in the **Product Discovery track** (brainstorm → visual-companion → ui-mockup ⟳ → concept-sync → requirements-engineer), and it is equally valid in the full 0-to-7 chain whenever mockups were iterated after the concept was written.

## When To Use

- Mockups in `5_mockups/` were changed after the concept was approved.
- `5_mockups/iteration-log.md` exists with logged change entries.
- The team has reached agreement on the mockups and wants the concept to match.
- Requirements should be written next, and they must consume an up-to-date concept.

## When To Skip

- The concept and mockups never diverged (no iteration happened).
- The change log is empty.
- You are still mid-iteration — keep iterating in `ui-mockup` first.

## Decomposed PROJ Handling

Work one PROJ at a time. If the concept contains `Decomposition Context`:

- Sync only the current PROJ's concept against its own iteration log.
- Do not pull sibling PROJ scope into this concept.
- If an iteration revealed new scope that belongs to a sibling PROJ, record it under `## Future Scope` or as a cross-PROJ dependency, not as new behavior in this concept.

## Input

Read these inputs:

1. Concept: `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`
2. Mockup iteration log: `specs/PROJ-<X>-<theme>/5_mockups/iteration-log.md`
3. Current mockups: `specs/PROJ-<X>-<theme>/5_mockups/*.html`
4. UI implementation handoff: `specs/PROJ-<X>-<theme>/5_mockups/implementation-handoff.md`
5. Optional Visual Companion decision: `specs/PROJ-<X>-<theme>/2_visual-companion/layout-decision.md`

If `iteration-log.md` does not exist but mockups clearly changed, reconstruct the change set by comparing the current mockups against the concept and ask the user to confirm what was decided. Then write the missing log so the trail is not lost.

## Workflow

### 1. Build The Change Set

Read `iteration-log.md` and the current mockups. For each logged change, classify it:

- **Scope change** — a flow, screen, capability, or user goal was added, removed, or reshaped.
- **Behavior change** — a rule, state, or interaction outcome changed in a way that affects requirements.
- **Presentation-only** — pure layout/visual change with no effect on the concept (note it, do not propagate it).

Only scope and behavior changes flow into the concept. Presentation-only changes stay in the mockups and the UI handoff.

### 2. Reconcile Into The Concept

Update `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md` so it again describes the agreed product:

- Update the relevant concept sections (goals, scope, flows, constraints, assumptions, risks).
- Where the iteration **replaced** an earlier concept decision, update the text and record the old decision under `## Superseded Decisions` with a one-line reason.
- Where the iteration **added** scope, add it to the concept's scope/flows.
- Where the iteration **dropped** scope, move it to `## Future Scope` or mark it out of scope — do not silently delete it.
- Keep the concept at concept altitude: no acceptance criteria, no API/schema design, no component file paths. Behavior and scope only.

Add or update a sync trailer at the end of the concept:

```markdown
## Concept Sync Log
- <date>: Synced from mockup iteration <N>. <one-line summary of what changed in the concept>.
```

### 3. Mark Abandoned Directions

If the iteration abandoned an approach that the concept or Visual Companion previously committed to, record it explicitly so it is not re-proposed later:

```markdown
## Superseded Decisions
- Was: <original concept decision>
- Now: <agreed decision after iteration>
- Reason: <why it changed during mockup review>
```

### 4. Review With The User

Show the user a concise diff-style summary:

- What changed in the concept and why.
- Which mockup changes were treated as presentation-only and intentionally not propagated.
- Which decisions were superseded.
- Anything ambiguous that needs a decision before requirements.

Ask one question at a time for anything unresolved. Only continue after the user confirms the concept now matches the agreed mockups.

### 5. Signal Handoff Readiness

Once the concept matches the mockups and the user approves, write a short readiness marker so downstream skills know the concept is reconciled:

```markdown
## Handoff Readiness
- Concept reconciled with mockups: yes
- Open questions for requirements: <none | list>
- Delivery track: discovery (Linear handoff) | full chain (in-repo build)
```

Place this section in the concept. Set `Delivery track` based on how this PROJ will be delivered:

- **discovery (Linear handoff):** No in-repo implementation here — `requirements-engineer` produces a developer handoff for Linear and the chain stops at Step 2.
- **full chain (in-repo build):** Steps 3–7 will follow in this repo.

If unsure, ask the user.

### 6. Handoff

After approval, recommend `requirements-engineer` (2):

- For the **discovery track**, tell `requirements-engineer` to run in **Linear handoff mode**: PRDs plus a paste-ready `linear-import.md`, no in-repo implementation notes.
- For the **full chain**, hand off normally.

The reconciled concept, the current mockups, and the implementation handoff are the inputs to requirements.

## Completion Checklist

- [ ] Iteration log read (or reconstructed and saved if it was missing)
- [ ] Each change classified as scope, behavior, or presentation-only
- [ ] Scope and behavior changes reflected in the concept
- [ ] Dropped scope moved to Future Scope, not deleted
- [ ] Superseded decisions recorded with reasons
- [ ] `Concept Sync Log` trailer added/updated
- [ ] `Handoff Readiness` section added with delivery track set
- [ ] User reviewed the change summary and approved
- [ ] Correct `requirements-engineer` mode recommended

## Git Commit Format

```text
docs(PROJ-<X>): Sync concept with mockup iterations for <theme>
```

Git is optional on the discovery track. If the workspace is not a git repository, skip the commit; the reconciled concept file is the durable artifact.
