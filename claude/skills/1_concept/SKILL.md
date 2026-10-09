---
name: concept
description: "Turn a feature idea or supplied problem brief into an approved buildable concept. Clarify the problem only when no usable clarification artifact exists, then compare directions, scope the work, and hand off to visual-companion or requirements-engineer."
---

# Concept: From Idea To Feature Concept

## Purpose

Turn a feature idea or stakeholder brief into one or more approved, buildable feature concepts at `specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md` (the chain-guide Step 1 output). This starts the PROJ chain: it fixes the PROJ number, theme slug, folder, scope boundary, assumptions, and first handoff. `visual-companion`, `frontend-design`, `prototyping`, `requirements-engineer`, `architecture`, `writing-plans`, `executing`, `qa`, and `documentation` all build on it, so each concept must be stable enough that nobody re-litigates the basic feature intent. Do not leave ambiguity unresolved because a later step exists.

Not free-form ideation and not implementation planning. Work in two passes: **Clarification** establishes the problem, users, success factors, non-goals, and constraints without choosing a solution; **Concept** decides the project boundary, compares directions, and fixes scope. A seed too broad for one PROJ is cut into separate PROJs with explicit dependencies first.

<HARD-GATE>
Do NOT invoke any implementation skill, write code, scaffold a project, edit production files, or create an implementation plan until you have presented a feature concept and the user has approved it.
</HARD-GATE>

<HARD-GATE>
Do NOT fill gaps with assumptions. If you catch yourself thinking "I assume the user means X", ask the user instead. Probable is not certain.
</HARD-GATE>

<HARD-GATE>
A vague "yes" is not clarification. Answers like "yes", "looks fine", "should work", "probably", "I think so", or "mostly" are non-answers when a concrete decision is needed. Re-ask with specific alternatives.
</HARD-GATE>

Ask one question per response unless the user explicitly asks for a checklist or wants to move fast. Inspect the project instead of asking when it can answer. Prefer multiple-choice questions when helpful; ask open-ended when options would bias useful context.

## Boundary

Concept owns: feature intent and problem framing; primary users and real scenarios; current workflow or pain; business/product success criteria; scope (in, out, later); product-level constraints, dependencies, risks, and trade-offs; high-level implementation success (what must be true for the implementation to count as successful, not how); and whether the feature has UI (→ `visual-companion`) or is pure backend/API (→ `requirements-engineer`).

Concept does **not** own the following. When a question drifts there, record it as a downstream input, handoff note, or open decision instead of resolving it:

- UI container choice (sidepanel, modal, drawer, split view, wizard, dedicated page) → `visual-companion`.
- Visual design language, colors, typography, spacing, style → `frontend-design`.
- Screen lists, sitemap, detailed UI states, component reuse, UI implementation handoff → `prototyping`.
- User stories, acceptance criteria, detailed edge-case matrices → `requirements-engineer`.
- Architecture, data model, API design, package choices, implementation strategy → `architecture`.
- Wave plans, tasks, tests, file ownership, production code → `writing-plans`, `executing`.

For UI features, concept may record product vocabulary, required high-level states, content examples, and existing behavior to preserve.

## Checklist

Create a task for each item and complete them in order:

1. **Explore project context** - before asking, read `README.md`, `docs/`, `specs/INDEX.md`, existing PROJs and their decisions, `AGENTS.md`, routes, screens, components, APIs, schemas, theme files and component registry, deployment and platform constraints (runtime, storage, env vars, cron, serverless limits), and recent commits. Summarize briefly. On the discovery track for an existing product without a local codebase, run [Brownfield Context Intake](#brownfield-context-intake-discovery-track) instead or in addition.
2. **Clarify the problem** - see [Clarification](#clarification).
3. **Run the decomposition gate** - see [Project Decomposition Gate](#project-decomposition-gate). If `specs/product-roadmap.md` exists, the cut and the PROJ number are already decided there: take the entry's user outcome, `Depends on`, and boundaries as given, and set its `Status` to `concept`. Only decompose further if this single entry turns out to be more than one PROJ — then split it in the roadmap too, with a changelog line.
4. **Approve project boundary** - explicit user approval for one PROJ or the multi-PROJ map before feature intake.
5. **Choose processing order** - for a multi-PROJ map, confirm whether to write only the first concept or all concepts in dependency order.
6. **Collect feature-concept intake** - see [Intake](#intake).
7. **Research if needed** - browse only for current, niche, regulated, or unfamiliar technical/domain context.
8. **Clarifying questions** - one at a time until the remaining gaps in [Clarifying Questions](#clarifying-questions) are covered.
9. **Controlled exploration and approaches** - see [Exploration](#exploration).
10. **Assumption playback** - read back every assumption and wait for confirmation or correction.
11. **Devil's-Advocate pass** - 3-5 weaknesses, risks, or tensions, each resolved or explicitly accepted.
12. **Explicit clarity confirmation** - ask exactly: "From your perspective, is everything now clear, or are there still unclear or open points?" Only an unambiguous answer ("everything is clear", "nothing is unclear anymore") lets you proceed; anything vague or partial sends you back to clarification.
13. **Present the feature concept** - in [template](#concept-document) order, scaled to complexity; ask for approval after each section when the concept is large or nuanced. Do not over-specify implementation.
14. **Allocate PROJ-X and theme slug** - scan `specs/PROJ-*/`, pick the next free integer (or the roadmap's number), agree on a kebab-case theme. Only after the boundary is approved.
15. **Create PROJ folder and state** - create `specs/PROJ-<X>-<theme>/1_concept/`, then run `bash ~/.claude/skills/5_executing/scripts/state.sh init <X> <theme>`. Write captured brownfield context to `0_context/` now. The new file stays `CP1:pending`; only the Step 5 checkpoint subskill may approve it.
16. **Write the concept doc and self-review** - see [Concept Document](#concept-document) and [Self-Review](#self-review); commit.
17. **Automatic cross-review** - see [Cross-Review](#automatic-cross-review).
18. **User reviews the written concept** - see [User Review And Transition](#user-review-and-transition).
19. **Repeat or transition** - next approved PROJ of the map, or hand off.

## Brownfield Context Intake (Discovery Track)

The discovery track usually has no codebase to scan. When the work extends something that already exists — a live product, design system, brand, domain vocabulary — capture it so it is not lost. Skip this for greenfield discovery and for the full in-repo chain (the repo scan covers it). Gather the references during context discovery, before the decomposition gate; write the files once the PROJ number and theme are approved (checklist step 14).

Ask what exists and gather: **existing surfaces** (live URLs or screenshots), **design system/brand** (Figma/Storybook/styleguide links, colors, fonts, component library, UI screenshot), **vocabulary** (domain terms that must not be renamed, with spelling), and **constraints and invariants** (rules, integrations, behaviors to preserve). You may fetch a provided URL and read provided screenshots; record only what the user confirms or a reference clearly shows.

Write to `specs/PROJ-<X>-<theme>/0_context/existing-state.md` (references in `0_context/references/`):

```markdown
# Existing State — PROJ-<X> <theme>

## Existing Product / Surfaces
- <URL or screenshot ref> — what it is, what it covers

## Design System / Brand
- Source: <Figma/Storybook/styleguide link or screenshot>
- Colors / fonts / spacing / radius conventions:
- Component library / patterns to reuse:

## Domain Vocabulary
| Term | Meaning | Notes (spelling, do-not-rename) |
|------|---------|---------------------------------|

## Existing Constraints And Invariants
- <rule / integration / behavior that must be preserved>

## Open Questions About The Existing State
- <anything unconfirmed>
```

`visual-companion` grounds layout exploration in it, `prototyping` uses it in design-system mode (no `tailwind.config` on this track), and `handoff-package` folds it into the package. Record in the concept's `Project Context` that it is the source of as-is truth.

## Clarification

Before exploring solutions, establish the problem owner (and deputy if relevant), job to be done, current pain, outcome/adoption/guardrail success factors with known baselines and targets, non-goals, and constraints. Keep success factors in business terms; measurement implementation belongs later. Do not choose scope, solution direction, UI, or technology in this pass.

Use a stakeholder brief from `clarification` (1a, `specs/_clarification/<slug>-stakeholder_brief.md`) or another user-provided clarification artifact as the source when it covers these points. Record its path or link in the concept and skip questions it answers. If no artifact exists, gather the missing facts conversationally and preserve them in the concept's `Clarification` section. Do not require a separate brief file or gate record.

A stakeholder brief from `clarification` was confirmed by the stakeholder, usually without the PM who now runs concept being able to re-ask them:

- Take confirmed facts as given; do not ask the PM to re-confirm them.
- For each open question, first ask whether it has been answered since. A still-open question marked `Blocks concept? yes` is a stakeholder follow-up: report it with its owner and do not select a direction until it is resolved. Non-blocking ones carry into `Open clarification questions`.
- If the PM's direction would contradict the stakeholder brief (for example, widen a non-goal), flag it as needing the problem owner instead of overriding it silently.
- Never edit the stakeholder brief. If it no longer holds, ask for a new revision via `clarification`.
- When one stakeholder brief is decomposed into several PROJs, every sibling concept cites the same stakeholder brief.

## Project Decomposition Gate

Run after clarification and before detailed intake. Concept owns product boundaries; PRDs split behavior inside a PROJ and waves split implementation order, so neither can fix a wrong project cut. Split by distinct user outcomes, not by a proposed solution's parts.

Split into multiple PROJs when two or more hold:

- Independent user goals that can ship, test, or be adopted separately.
- Different subsystems with different owners, risk profiles, data models, or rollout paths.
- Foundation/enabling work mixed with user-facing workflows.
- Multiple audiences whose success criteria differ materially.
- Several PRDs with weak dependencies between them.
- Separate UI exploration paths, such as admin tooling plus end-user workflow.
- A risky or unknown piece that should be isolated first.
- MVP-critical work mixed with expansion, automation, analytics, migration, support tooling, or polish.

Skip the split only for one coherent user outcome, one main audience, and one downstream path. Do not decompose only because a feature is complex; keep one PROJ when the pieces must be designed, shipped, and validated together to create user value.

If the seed is too broad, stop detailed questioning and propose a map, using temporary labels until approval:

```markdown
This seed looks larger than one PROJ. I recommend splitting it into:

1. PROJ-A candidate: <theme>
   - User value:
   - Scope:
   - Explicitly not included:
   - Depends on:
   - Suggested downstream path: visual-companion | requirements-engineer

2. PROJ-B candidate: <theme>
   - User value:
   - Scope:
   - Explicitly not included:
   - Depends on:
   - Suggested downstream path: visual-companion | requirements-engineer

Recommended first PROJ: <theme>, because <reason>.
```

Ask: "Does this project split match your intent, or should any of these be merged, removed, renamed, or reordered?" A vague yes is not enough while boundaries are unresolved; re-ask with concrete merge/remove/reorder options.

After approval: allocate real PROJ numbers only now; one folder and concept per PROJ; process concepts one at a time in dependency order if the user wants all of them now; each concept fills `Decomposition Context` (original seed, approved map, this PROJ's role, siblings and boundaries, dependencies and order, scope assigned elsewhere); a PROJ blocked by another gets the next step "wait for PROJ-<X>". If the user rejects decomposition, record why the broader scope is acceptable as one PROJ under `Risks And Trade-Offs`.

## Intake

Collect before converging, not all up front: inspect the project first, take problem facts from the clarification source, then ask only for missing or ambiguous inputs.

**Required:** feature seed; primary users and concrete scenarios; current workflow or pain; success criteria as observable or measurable signals; scope (in, out, later); project boundary; constraints (technical, data, auth, privacy, compliance, mobile/desktop, timeline, operational, deployment).

**Conditional, only when relevant:** data ownership (created, read, updated, deleted, imported, exported, retained); permissions by role; failure handling for external services, database, uploads, model calls, background tasks; migration or compatibility for existing users, data, APIs, URLs, settings, integrations; auditability (logs, history, approvals, rollback); shareability and deep links; volume and performance (counts, sizes, traffic, latency, concurrency); internationalization and time zones.

**Implementation success, product level only:** what makes the delivered feature feel successful to users and stakeholders; what must stay true about the existing product; which constraints would make an otherwise correct implementation unacceptable; which operational failures must be avoided or handled gracefully; which downstream artifact needs special attention. Record answers as success conditions, constraints, risks, or handoff notes — never as a technical design.

**Shaping, to choose a direction rather than inflate scope (YAGNI):** concept emphasis (MVP slice, UX, feasibility, decomposition, risk reduction), implementation appetite (tactical change, solid MVP, extensible foundation, high polish), risk tolerance (conservative, balanced, experimental), decision priority (speed, correctness, UX, maintainability, cost, compliance, extensibility).

## Clarifying Questions

Cover only gaps the clarification source and intake left open:

- **Success criteria:** make unclear outcomes, adoption, guardrails, baselines, or targets concrete.
- **Scope:** define in, out, and later without silently changing clarified non-goals.
- **Users and scenarios:** fill missing usage contexts for the chosen direction.
- **Edge cases:** consequential failures or exceptions that could change direction or scope.
- **Product terms**, sharpened as ambiguities surface, not as a separate round: propose one canonical term for a fuzzy or overloaded one ("the Customer or the User?"); call out conflicts with `docs/PRODUCT.md`, `0_context/existing-state.md` (Domain Vocabulary), or earlier answers immediately; invent borderline scenarios ("does X count as Y?") and make the user decide; in a brownfield repo, check stated behavior against the code and surface mismatches. Write each settled term or scenario into `Key Terms And Disputed Scenarios` right away, free of implementation detail — no `GLOSSARY.md`, no technical ADRs.

## Exploration

Explore product-level alternatives before converging so the first plausible idea does not win by inertia. Pick the mode from context; ask only if it is genuinely ambiguous: practical options (2-3 realistic approaches), broad exploration then narrowing, briefly a few wild or constraint-breaking options to extract lessons, or progressive flow (broad, cluster, select). Do not target dozens of ideas. When stuck, pivot internally through 3-5 lenses (UX, feasibility, existing-system fit, data ownership, security/privacy, operations, edge cases, cost/latency/runtime, extensibility, what is not being built) — not as a questionnaire. For UI features, identify UI tensions for `visual-companion`; never choose the container.

Then propose 2-3 approaches, each with what it is, best fit, trade-offs, scope impact, and main risks. Lead with your recommendation and why, accounting for project context, goals, success criteria, constraints, and out-of-scope boundaries.

**Assumption playback:** "I derived the following assumptions from your answers. Please confirm or correct each one:" followed by a numbered list. Separate confirmed inputs (stated by the user or found in the project), assumptions (need confirmation), and open questions. Corrections trigger follow-up questions, not silent re-derivation.

**Devil's-Advocate pass:** list 3-5 weaknesses or tensions, for example an undefined threshold behind "fast", a support recovery path excluded by out-of-scope, concurrent edits without conflict behavior, or durable background work on a serverless target. The user resolves each or accepts it as a conscious risk.

## Concept Document

Write after approval. The template is the output contract: downstream skills must be able to proceed from it without repeating discovery.

```markdown
# PROJ-<X> Concept - <theme>

## Status
Approved concept

## Feature Seed

## Decomposition Context
- Original broader seed:
- Approved project map:
- This PROJ's role:
- Sibling PROJs:
- Depends on:
- Blocks:
- Scope intentionally assigned to another PROJ:

## Project Context
- Existing system:
- As-is reference (discovery track): `0_context/existing-state.md` if captured
- Relevant constraints:
- Prior related specs:

## Clarification
- Source: <supplied artifact path/link | captured in this concept>
- Problem Owner / deputy: <if known>
- Job to be done: <when, who, goal, benefit>
- Success factors: <outcome, adoption, guardrail; known baselines and targets>
- Non-goals and constraints: <from clarification>
- Open clarification questions: <none | list>

## Problem And Goal

## Primary Users And Scenarios

## Current Workflow Or Pain

## Success Criteria

## Scope
### In Scope
### Out Of Scope
### Later

## Selected Direction

## Key Behaviors And Flows

## Data, Permissions, And Constraints

## Key Terms And Disputed Scenarios
- <term>: <definition in one sentence; what counts, what does not>
- <borderline scenario> → <agreed outcome and why>

## Error Handling And Edge Cases

## High-Level Implementation Success
- User/stakeholder success:
- Product constraints:
- Operational constraints:
- Existing behavior to preserve:
- Downstream attention needed:

## Downstream Handoff Notes
- For visual-companion: <primary user job and context; information shape (list/detail, form-heavy, review/approval, timeline, dashboard, wizard-like, other); likely UI tensions without choosing a container; mobile importance, deep links, destructive actions, context preservation; UI anti-goals>
- Mockup-relevant product inputs: <vocabulary, high-level states, content examples, behavior to preserve>
- For requirements-engineer: <major behaviors; product-level edge cases and failure expectations; constraints PRDs must preserve>
- For architecture/planning: <constraints with technical implications; data ownership, permission, and external dependency hints; operational risks, durability, latency; existing behavior to preserve; explicit non-goals against overbuilding>

## Explored Alternatives
### Alternative A
- Summary:
- Why not selected:

### Alternative B
- Summary:
- Why not selected:

## Assumptions Confirmed

## Risks And Trade-Offs

## Testing Focus

## Next Step
- UI feature: visual-companion
- Backend/API feature: requirements-engineer
```

Keep it product-level and decision-rich; no PRDs, architecture, or implementation plan. Commit with `feat(PROJ-<X>): add concept for <theme>`. Git is optional on the discovery track: without a repository, skip the commit (or suggest an optional `git init` for a history of concept and mockup iterations); the file itself is the durable artifact.

## Self-Review

Before the user reviews it, check the written concept and fix issues inline; ask the user when a fix needs unconfirmed information:

1. **Placeholders:** no `TBD`, `TODO`, empty sections, or vague words standing in for decisions.
2. **Consistency:** direction, scope, users, success criteria, and risks do not contradict each other.
3. **Scope:** focused enough for one PROJ, or decomposed with map, siblings, dependencies, and excluded sibling scope documented.
4. **Ambiguity:** requirements cannot be read in materially different ways; key terms are defined and disputed scenarios settled.
5. **Coverage:** success criteria, out of scope, and users/scenarios are explicit; rejected alternatives and confirmed assumptions are recorded; unresolved assumptions are not hidden.
6. **Contract:** every template section, including the downstream handoff notes for the chosen path, is filled.
7. **Boundary:** nothing from the [Boundary](#boundary) "does not own" list leaked in; implementation success reads as product constraints, risks, or handoff notes, not technical design.

## Automatic Cross-Review

Immediately after saving the concept, invoke `cross-review` in the same turn,
before user review or transition. Do not ask whether to run it or wait for
approval. Supply everything that establishes as-is truth for the concept:

```bash
bash scripts/cross-review.sh concept <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md \
  --ground-truth specs/PROJ-<X>-<theme>/0_context/existing-state.md \
    docs/PRODUCT.md specs/product-roadmap.md \
  --author-provider <current-writer> --round 1
```

Drop any path that does not exist — the script fails on a missing file, and on
the discovery track most of these may be absent. The grounding check ("claims
about the existing product agree with the supplied context") is only as good as
what you supply: with no ground truth at all, say so to the user rather than
presenting the result as a grounded review.
Follow `cross-review`'s automatic reconcile/re-review loop through round 3
while findings of any severity remain; stop early when clean. Escalate remaining
Critical/High findings before transition. Ask only for unresolved product
decisions. Additional manually requested rounds have no limit.

## User Review And Transition

Ask:

> "Concept written and committed to `specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md`. Automatic cross-review is complete. Please review the concept before we continue. Let me know if you want to make any changes."

Apply requested changes and self-review again; proceed only after approval. Then:

- UI feature → invoke `visual-companion`. Pure backend/API → invoke `requirements-engineer`.
- If the PROJ depends on an uncreated or unapproved sibling, create or approve that prerequisite first.
- For a multi-PROJ map, repeat for the next approved PROJ; later skills run per PROJ unless the user asks to continue several in sequence.
- Never invoke writing-plans, architecture, executing, QA, documentation, or implementation directly from concept.
