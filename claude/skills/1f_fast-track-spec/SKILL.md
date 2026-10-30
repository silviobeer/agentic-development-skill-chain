---
name: fast-track-spec
description: "Compressed entry path for a small, well-bounded, non-bug change: concept, one PRD and the architecture in ONE session with ONE interview and ONE cross-review, written as the standard artifacts so planning and execution run unchanged. Use when: (1) the task is a small feature or product change with one PRD and a handful of stories, (2) it needs no UI exploration (existing components only), (3) no product decision is open. Not for: bugs (use bugfixing), more than one PRD, new screens or layouts, stack or baseline changes, a task still unclear in scope (use concept). Escalates to concept when the interview finds otherwise."
---

# Fast-Track Spec (1f)

## Session Boundary

Through Step 4, each producing skill runs in its own user-started session.
Complete this skill's checks, automatic cross-review, reconciliation and required
user review here, then stop at the handoff. Do not invoke the next producing
skill, including a prerequisite or another PROJ, in this session. Internal
helpers and cross-review remain in this session. `/compact` is not a new session.
End with a copyable start prompt naming the next skill, workspace, PROJ (if any),
actual input artifact paths and any blockers. The next session reads those
artifacts rather than relying on chat history. Do not create a separate session-context file.
If blocked, name the owning skill and issue in the prompt; do not claim readiness.

## Purpose

Spec-driven development with a shorter front half. One session replaces steps 1, 2 and 3 (run this instead of them, not in addition) and writes the **standard** artifacts, thin but valid, so `writing-plans` and everything after run untouched:

- `specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md`, including `Handoff Readiness`
- `specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-1-<desc>.md` with `PROJ-X-PRD-Y-US-Z-AC-N` IDs
- `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md` with `**Summary:**` lines

Never invent a combined spec format: the validators and the worker-context compiler read these files. Thin means short, not skipped; every required section stays.

**Reuse, don't restate.** Read only the named parts of the owner skills and follow them; this file adds only what differs.

| Owner | Follow |
|---|---|
| [concept](../1_concept/SKILL.md) | the HARD-GATEs (no assumptions, a vague "yes" is not an answer), [Boundary](../1_concept/SKILL.md#boundary), the [Concept Document](../1_concept/SKILL.md#concept-document) template, [Self-Review](../1_concept/SKILL.md#self-review) |
| [requirements-engineer](../2_requirements-engineer/SKILL.md) | [Feature Granularity](../2_requirements-engineer/SKILL.md#feature-granularity), the PRD template (§ 4), edge-case list (§ 3) |
| [architecture](../3_architecture/SKILL.md) | Rules, Library Scan, Output template and Summary rules |
| [cross-review](../cross-review/SKILL.md) | the reconcile / re-review loop through round 3 |

## Language

Write all three artifacts in English (a mixed-language set is awkward and the architecture-mode review flags non-English prose); converse in the user's language.

## Workflow

### 1. Preconditions and context

`docs/PRODUCT.md` must exist, else stop and route to `chain-guide` (baseline first). Read `docs/PRODUCT.md`, the roadmap entry if any, `docs/ARCHITECTURE.md` (§ Stack and load-bearing parts) and `docs/GUIDELINES.md`. Spawn one read-only Explore agent for the area the task touches (routes, components, API/schema entry points, PROJs touching the same area, recent commits) and keep only its short answer, including the source paths supporting reuse and placement claims for the review in step 7. A supplied clarification artifact or stakeholder brief replaces the matching questions; retain its path for that review.

### 2. One interview

One question per turn, inspect the repo instead of asking where it can answer. Cover, in this order, only what is still open:

1. Problem, users, observable success, non-goals, constraints.
2. Is the solution direction fixed? If yes, record it in one line in `Selected Direction` and skip Opening. If not, offer 2-3 options that differ in kind (not variants), let the user pick, and write every dropped option to `PROJ-<X>-direction-log.md` in the [concept's format](../1_concept/SKILL.md#direction-log).
3. **Playback draft**: you draft the stories (Given/When/Then), their ACs, edge cases and the architecture decisions with the Library Scan result, in one message. The user corrects the draft instead of answering open questions. Ask the architecture questions only where the draft cannot settle them (roles, integrations, rollback).
4. Assumption playback, Devil's-Advocate pass (3-5 items) and the exact clarity question from concept checklist step 13.

### 3. Fit gate (before any number is allocated)

Present the verdict and get explicit confirmation. Fast track holds only if **all** are true:

- One PRD: the Feature Granularity split test yields one unit.
- At most 5 stories.
- No UI exploration: no new screen, layout or visual decision; existing components only.
- No open product decision: nothing deferred, no blocking stakeholder question, no vague answer left.
- No `Changes baseline` decision, live-data migration, new external integration or trust boundary.

### 4. Escalate when the gate fails

Allocate nothing. Write `specs/_fast-track/<slug>-escalation.md` (raw input, not a concept): the seed; what the interview established (problem, users, success, non-goals, constraints, drafted stories) marked unconfirmed; the failed criterion with its evidence; the candidate PRD split or open decision. End with the start prompt `/1_concept specs/_fast-track/<slug>-escalation.md` and the reason. Stop.

The same applies if the trigger appears after files exist (cross-review or user review surfaces a second PRD or an open product decision): keep the artifacts as written, but make the folder unreadable as a ready fast-track PROJ: in the concept's `Handoff Readiness` delete the `Authored via: fast-track-spec` bullet (the QA risk check then reads `full`) and add `- Blocked: escalated to concept, see specs/_fast-track/<slug>-escalation.md` (write that escalation file as above). Name `concept` as owner in the start prompt with the concept and PRD paths as input, and do not claim readiness.

### 5. Allocate and open the PROJ

- **Number:** if the roadmap has a matching `planned` row, use its number; otherwise the next integer above the highest number found in `specs/PROJ-*/` **and** the roadmap rows (numbers are never reused). Agree the kebab-case theme.
- Create `specs/PROJ-<X>-<theme>/1_concept/`, then `bash ~/.claude/skills/5_executing/scripts/chain state init <X> <theme>` (the persisted cross-review needs `state.json`; it stays `CP1:pending`).
- **Roadmap** (only if `specs/product-roadmap.md` exists; never create one): set a matching row to `concept`, or append `| PROJ-<X> | <theme> | <one-sentence user outcome> | — | concept |` and a `## Changelog` line `YYYY-MM-DD — PROJ-<X> added via fast-track-spec`. Never rewrite another row.

### 6. Write the three artifacts

Concept → PRD → architecture, each from its owner's template:

- **Concept:** every template section filled in one to three lines; aim for 80 lines, the 150-line cap stays. `Decomposition Context`: single PROJ. `Handoff Readiness`: exactly two bullets, each on its own line, with no trailing text: `- Delivery track: full chain (in-repo build)` and `- Authored via: fast-track-spec` (the marker `chain check risk` reads; any other shape reads as a full-chain PROJ). `Direction Log`: the file when options were dropped, else "none". `Next Step`: `writing-plans` (PRD and architecture already exist), never visual-companion or requirements-engineer.
- **PRD:** one file `PROJ-<X>-PRD-1-<desc>.md`, at most 5 stories, each with its own ACs. `UI Implementation Notes` only when stories touch existing UI, naming the components to reuse.
- **Architecture:** `Overview` (2 sentences), `PRDs Covered`, and at least one `### Decision N` with `**Affects:**` and `**Summary:**` (the validator rejects an empty or prose-only section). Its Summary is the only line workers see, so a task with nothing significant records the real placement, e.g. "Extend <module/pattern>; no new boundary, dependency or data", not a ritual "none". Further sections only when the Rules call for them; no diagrams unless a decision needs one. Stack is inherited; never edit `docs/`.

### 7. Gates and one cross-review

```bash
CHAIN=~/.claude/skills/5_executing/scripts/chain
bash $CHAIN check prds specs/PROJ-<X>-<theme>/2_PRDs
bash $CHAIN check architecture specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md specs/PROJ-<X>-<theme>/2_PRDs
[ "$(wc -l < specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md)" -le 150 ]
```

Re-run after every change; a failure blocks review and handoff. Then, in the same turn and without asking, run **one** review of the whole set. Use the installed `chain` above, not a project-local `scripts/chain`, which may predate `--also-focus`:

```bash
bash $CHAIN review architecture <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md \
    specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-*.md \
    specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md \
  --ground-truth docs/PRODUCT.md docs/ARCHITECTURE.md docs/GUIDELINES.md specs/product-roadmap.md \
  --also-focus concept,requirements \
  --author-provider <current-writer> --persist --round 1
```

Drop ground-truth paths that do not exist. Add any supplied clarification artifact or stakeholder brief to `--ground-truth`, together with the existing source files that support the architecture decisions (named extension points, reused components and patterns), including relevant paths from the Explore answer. Pass the actual files so the read-only reviewer can verify the claims. Keep the mode `architecture` and `--persist`: CP1's fast path reads that record (findings land in `3-4_plan/findings.json`). Reconcile findings of any severity (rewrite the artifact as if right the first time, no narrated corrections) and re-review with `--round 2`, then `--round 3`, while findings remain; stop when clean. Remaining Critical/High findings after round 3, or exit `1`, block the handoff and go to the user; ask only about unresolved product decisions.

### 8. User review and handoff

Present the three artifacts and the review result once. Apply requested changes, repeat the gates and the review on the revised set. After approval commit once: `docs(PROJ-<X>): Add fast-track concept, PRD and architecture for <theme>`.

Say once: "Fast-track spec is ready in `specs/PROJ-<X>-<theme>/`. Cross-review: <clean | N findings reconciled>. Start **writing-plans** in a new session with the prompt below; you approve architecture and plans together at Checkpoint 1." Then give the copyable start prompt for **writing-plans** (4) with this workspace, PROJ, the architecture path and the PRD directory.

## Completion Checklist

- [ ] Fit gate confirmed by the user (or escalated, nothing allocated)
- [ ] PROJ number checked against folders and roadmap; roadmap row set if a roadmap exists
- [ ] `chain state init` run; concept, one PRD and architecture written and English
- [ ] `check prds`, `check architecture` and the concept cap pass
- [ ] One persisted `architecture` cross-review with `--also-focus concept,requirements`; no open Critical/High
- [ ] User approved; one commit; start prompt for writing-plans given
