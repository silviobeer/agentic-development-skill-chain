---
name: review-reconcile
description: "Resolve a developer or stakeholder review of finished PRDs by going through the raised gaps point by point, deciding each with the product owner or deferring it to a developer meeting, then reconciling the agreed outcomes back into the PRDs, concept, and mockups. Use after requirements-engineer (and any handoff) when a review comes back with gaps, ambiguities, or open questions on the PRDs. Records a decision log, keeps unresolved items as an explicit developer-meeting agenda, and maintains a handoff-facing changelog so external teams (UI/UX, devs) can follow what changed since the version they reviewed. Sibling of concept-sync on the Product Discovery track."
---

# Review Reconcile — Resolve PRD Review Feedback Into The Artifacts

After PRDs are written (and often after they were handed to a developer), a review comes back: a list of gaps, contradictions, ambiguities, and questions on the PRDs. This skill works through that review **point by point**, decides each item with the product owner or defers it to a developer meeting, and reconciles the agreed outcomes back into the PRDs, the concept, and the mockups — so the artifacts again match what was actually decided.

It is the post-requirements counterpart of `concept-sync`:

- `concept-sync` (1e): mockup iterations → concept, **before** requirements.
- `review-reconcile` (2c): review feedback → PRDs/concept/mockups, **after** requirements.

It produces a durable decision record, an explicit agenda of items that still need a developer meeting, and a handoff-facing changelog so downstream UI/UX experts and developers can trace what changed since the version they reviewed.

## When To Use

- PRDs exist (`requirements-engineer` is done) and a review of them came back.
- The review raises gaps, contradictions, open questions, or "decisions to resolve".
- The product owner needs to decide each point and have the PRDs updated to match.
- External teams (UI/UX, developers) will later need to see what changed and why.

## When To Skip

- No PRDs exist yet — write them first with `requirements-engineer` (2).
- The feedback is pure copyediting with no scope/behavior decisions (just edit the PRD directly).
- The change is a fresh mockup iteration, not a PRD review — use `ui-mockup` (1d) + `concept-sync` (1e).

## Core Principle

Decide before you edit. Capture every decision in a record **before** touching the binding PRDs, so the trail from "review gap" to "artifact change" is always reconstructable. Never silently resolve a gap by editing a PRD with no recorded rationale.

Not every gap is the product owner's to decide. Some require engineering input (architecture, feasibility, effort, security). Those are **deferred to a developer meeting**, not force-decided — they stay open with a clear status and land on an agenda.

## Decomposed PROJ Handling

Work one PROJ at a time. A review usually targets one PROJ's PRDs. If the review touches a sibling PROJ's scope, do not pull that scope in here — record it as a cross-PROJ dependency or `Future Scope` note and keep this PROJ's decisions local.

## Input

Read these inputs:

1. The review itself — pasted text or a file the user provides (gaps, questions, suggested updates).
2. Target PRDs: `specs/PROJ-<X>-<theme>/3_PRDs/*.md`.
3. The canonical scope/decisions source if one exists (e.g. `2_scope-open-decisions.md` or the concept's decisions register) — **read it first** so no decision contradicts a canonical rule.
4. Concept: `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md` (if it exists).
5. Mockups: `specs/PROJ-<X>-<theme>/5_mockups/*.html` + `iteration-log.md`.

If the review references decision IDs, rules, or sections, resolve them in the source documents before interpreting the gap — an answer that violates a canonical rule is wrong even if it closes the gap.

## Workflow

### 1. Create The Decision Record First

Before editing any binding artifact, create a decision record for this review round:

`specs/PROJ-<X>-<theme>/3_PRDs/<prd-stem>-review-decisions.md`
(or `PROJ-<X>-review-<NN>-decisions.md` when the review spans several PRDs).

Seed it with one entry per raised gap, each marked `Open`, plus a `Decision Summary` table and a `Developer Meeting Agenda` section (initially empty). Per entry, reserve fields: **Gap**, **Decision**, **Artifact follow-up** (per layer).

### 2. Go Through The Gaps Point By Point — Explain And Decide In One Loop

For each gap, in one pass:

1. **Explain it plainly** — what the review is flagging and *why it is a problem* (e.g. the same thing is specified two contradictory ways; an undefined state the system must handle). Translate jargon; if the user works in another language, explain in theirs while keeping the record in English.
2. **Frame the choices** — present the realistic options with a clear recommendation and the trade-offs visible. If the review suggests a "best practice", treat it as one option to confirm or override, not a default.
3. **Decide or defer, now:**
   - **Decide** — the product owner picks. Record the decision.
   - **Defer → developer meeting** — the item needs engineering input (feasibility, architecture, effort, security, provider constraints). Mark it `Open — needs developer meeting`, capture the specific question for engineering, and add it to the `Developer Meeting Agenda`. Do **not** force a product decision.
4. **Record immediately** in the decision record before moving on.

Ask one point at a time. Do not batch all gaps into a single prompt — the value is the focused decision per point.

### 3. Map Each Decision Across The Artifact Layers

For every decided item, identify which layers must change, and note it in the record as a small table:

| Layer | Change |
|---|---|
| PRD | exact user story / line and the new wording |
| Concept | scope/behavior update, or "n/a" |
| Mockup | the screen + wording/mechanism, or "n/a" / "already correct" |

This makes the blast radius explicit before editing and often reveals that a mockup is already correct or that no concept exists yet.

### 4. Apply The Edits, Layer By Layer

Apply only **decided** items (deferred ones change nothing yet):

- **PRDs are binding** — make the agreed edits precisely; align any contradicting lines (rules, open-decisions registers) in the same pass.
- **Concept** — if one exists, reconcile scope/behavior changes (do not invent a concept if none exists; note that the future concept should carry the decision).
- **Mockups are wireframe / workflow references, not the binding design.** Change a mockup only where it now *contradicts* the decided PRD. Do not invent screens or fake elements to "demonstrate" a rule; prefer encoding the mechanism plus a documented note. Log every mockup change in `5_mockups/iteration-log.md` (one entry per review round), classified scope / behavior / presentation-only.

### 5. Maintain The Handoff-Facing Changelog

So external teams (UI/UX expert, developers) can trace what changed since the version they reviewed, maintain a running, audience-facing changelog:

`specs/PROJ-<X>-<theme>/3_PRDs/review-changelog.md`

Append one round section per review:

```markdown
## Review round <NN> — <date> (<short label>)
Source: <who reviewed / review title>
- <PRD/area>: <what changed> — <one-line why> (decision <Qn>)
- <mockup/screen>: <what changed> (presentation-only | behavior)
Deferred to developer meeting: <Qn list, or none>
```

This is distinct from the internal decision record: the changelog is the short, reader-facing "what changed and why" that flows into the handoff. `handoff-package` (2b) folds it into the standalone deliverable so downstream readers see the delta without reading the full decision log.

### 6. Review With The User

Show a concise summary:

- Which gaps were decided and how.
- Which were deferred to the developer meeting (and the agenda that resulted).
- Which artifact layers changed; which mockups were already correct or intentionally left to the binding design step.
- Anything still ambiguous.

Confirm before finalizing. Update each decided entry's status to `Decided and applied`; keep deferred entries `Open` so the next round can close them.

### 7. Handoff

- If items were deferred: the `Developer Meeting Agenda` in the decision record is the ready-to-use agenda. After the meeting, re-run this skill for the remaining items.
- If a standalone deliverable is needed: recommend `handoff-package` (2b); it picks up `review-changelog.md`.
- Otherwise the updated PRDs are ready to go back into the review cycle / Linear.

## Completion Checklist

- [ ] Canonical scope/decisions source read before interpreting gaps
- [ ] Decision record created before any binding edit
- [ ] Every gap walked point by point: explained, framed, and decided or deferred
- [ ] Deferred items captured on the `Developer Meeting Agenda`, not force-decided
- [ ] Each decided item mapped across PRD / concept / mockup layers
- [ ] PRD edits applied; contradicting canonical lines aligned in the same pass
- [ ] Mockup changes limited to real contradictions; logged in `iteration-log.md`
- [ ] `review-changelog.md` updated for this round (handoff-facing)
- [ ] User reviewed the summary and approved
- [ ] Decided items marked applied; deferred items left open for the next round

## Git Commit Format

```text
docs(PROJ-<X>): Reconcile <review> feedback into PRDs and mockups for <theme>
```

Git is optional on the discovery track. If the workspace is not a git repository, skip the commit; the decision record, updated PRDs, and changelog are the durable artifacts.
