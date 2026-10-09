---
name: clarification
description: "Facilitate a live clarification session between a PM and a stakeholder and write a standalone stakeholder brief: job to be done, problem owner and deputy, outcome/adoption/guardrail success factors with baselines and targets, non-goals, constraints, and open questions. Use when: (1) a stakeholder brings a new feature request or problem and the PM wants it clarified before concept work, (2) the problem owner will not be present when the concept is written. Produces specs/_clarification/<slug>-stakeholder_brief.md, which 1_concept consumes later. Not for: choosing scope, solution direction, PROJ split, UI, or technology (use concept); product-level vision (use product-vision); defining measurement instrumentation."
---

# Clarification: Clarify The Problem With The Stakeholder

## Purpose

Capture what a stakeholder needs, in their terms, so a PM can later run `1_concept` without them in the room.

The usual setting: the PM and the stakeholder sit together, the PM drives this skill, the stakeholder answers. Later the PM picks up the stakeholder brief alone and runs `concept`. The stakeholder brief must therefore stand on its own: anything not written down is lost.

This is an optional step before `1_concept`. It does not allocate a PROJ number, decide scope, compare solutions, or split work into PROJs. Those belong to `concept`, which may turn one stakeholder brief into several PROJs.

<HARD-GATE>
Do NOT propose solutions, scope, UI, or technology, and do NOT define how success will be measured technically. If the stakeholder offers a solution, record the need behind it ("so that …") and note the idea under Open Questions as a suggestion for concept.
</HARD-GATE>

## Session Rules

- Speak the stakeholder's language. No chain vocabulary (PROJ, PRD, wave, architecture).
- Ask one question at a time. Prefer concrete examples ("last time this happened, what did you do?").
- Keep the stakeholder's own wording for the job to be done and the current pain; tidy grammar, not meaning.
- A vague answer to a decision the stakeholder can make now ("probably", "should be fine") is a non-answer: re-ask with concrete options.
- A question the stakeholder cannot answer in the session (unknown baseline, someone else decides) does not stall the session: record it under Open Questions with an owner and due date and move on.
- Inspect `docs/PRODUCT.md` and `specs/product-roadmap.md` before the session if they exist, so questions fit the product and contradictions surface live.

## Checklist

1. **Seed** - one or two sentences: what prompted this request?
2. **Problem owner and deputy** - who owns the problem and decides on trade-offs; who stands in when they are absent.
3. **Job to be done** - when <situation>, <who> wants <goal>, so that <benefit>. One or more jobs.
4. **Current pain** - what happens today, where it breaks down, how often, what it costs.
5. **Success factors** - in business terms, each with a known baseline and target or `unknown`:
   - *Outcome:* the business or user result that should change.
   - *Adoption:* who must use it, how much, by when.
   - *Guardrail:* what must not get worse.
6. **Non-goals** - what this explicitly should not achieve or include.
7. **Constraints** - deadlines, budget, regulation, policies, dependencies on other teams or systems.
8. **Open questions** - each with owner, due date, and whether it blocks concept work.
9. **Read-back** - read the stakeholder brief back section by section; the stakeholder confirms or corrects each section.
10. **Write and hand off** - write the file, set the status, and tell the PM the next step.

## Stakeholder Brief

Write to `specs/_clarification/<slug>-stakeholder_brief.md` (kebab-case slug agreed with the PM). If the file exists, add a new revision instead of overwriting: `<slug>-stakeholder_brief-r2.md`.

```markdown
# Stakeholder Brief - <working title>

## Status
draft | confirmed with <owner>, <YYYY-MM-DD>

## Seed

## Problem Owner
- Owner: <name/role>
- Deputy: <name/role | none>

## Job To Be Done
- When <situation>, <who> wants <goal>, so that <benefit>.

## Current Pain

## Success Factors
| Type | Factor (business terms) | Baseline | Target |
|------|-------------------------|----------|--------|
| Outcome | | <value / unknown> | |
| Adoption | | | |
| Guardrail | | | |

## Non-Goals

## Constraints

## Open Questions
| Question | Owner | Due | Blocks concept? |
|----------|-------|-----|-----------------|
```

Set `confirmed` only after the read-back. Commit with `docs(clarification): add <slug> stakeholder brief` when the workspace is a git repository.

## Handoff

The stakeholder brief is ready for concept when it is confirmed and no open question marked `Blocks concept? yes` remains. Tell the PM:

> "Stakeholder brief written to `specs/_clarification/<slug>-stakeholder_brief.md`. Next: run `/1_concept specs/_clarification/<slug>-stakeholder_brief.md` once the blocking questions are answered."

If blocking questions remain, list them with their owners instead of recommending concept.

`concept` reads the stakeholder brief as its clarification source: it skips questions the stakeholder brief answers, does not re-ask the PM to confirm what the stakeholder settled, and never edits the stakeholder brief. Changes after confirmation go into a new revision.
