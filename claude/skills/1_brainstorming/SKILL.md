---
name: brainstorming
description: "Use as Step 1 of the PROJ workflow before creating or changing any feature, component, workflow, or behavior. Turns a feature idea into an approved buildable concept through project discovery, structured intake, bounded exploration, assumption playback, and risk review. Produces specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md, then hands off to visual-companion for UI features or requirements-engineer for backend/API features."
---

# Brainstorming Ideas Into Feature Concepts

## Purpose

Turn a feature idea into a clear, buildable feature concept.

This is the start of the whole PROJ skill chain. It establishes the PROJ number, theme slug, project folder, concept document, scope boundaries, assumptions, and first handoff decision that every later skill depends on.

This is not free-form ideation and not implementation planning. The endpoint is always an approved buildable feature concept written to `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`, matching the process-guide Step 1 output.

The concept document defines the feature's purpose, users, scope, success criteria, constraints, explored approaches, selected direction, and known risks.

Start by understanding the current project context. Then collect the minimum inputs needed to shape the feature concept. Ask questions one at a time. Explore alternatives before choosing a direction. Do not proceed until the user confirms that nothing important is unclear.

<HARD-GATE>
Do NOT invoke any implementation skill, write code, scaffold a project, edit production files, or create an implementation plan until you have presented a feature concept and the user has approved it.
</HARD-GATE>

<HARD-GATE>
Do NOT fill gaps with assumptions. If you catch yourself thinking "I assume the user means X", ask the user instead. Probable is not certain.
</HARD-GATE>

<HARD-GATE>
A vague "yes" is not clarification. Answers like "yes", "looks fine", "should work", "probably", "I think so", or "mostly" are non-answers when a concrete decision is needed. Re-ask with specific alternatives.
</HARD-GATE>

## Core Rule

Ask one question per response unless the user explicitly asks for a checklist or wants to move fast. If a needed answer can be discovered from the project, inspect the project instead of asking.

## Chain Ownership

This skill owns the first durable artifact in the process:

```text
specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md
```

Later skills consume this artifact:

- `visual-companion` uses it to explore UI layout shape.
- `frontend-design` uses the selected UI direction when design language is needed.
- `ui-mockup` uses it plus visual/design decisions to create HTML mockups and implementation handoff.
- `requirements-engineer` uses it to write PRDs, user stories, acceptance criteria, and edge cases.
- `architecture` uses it with PRDs to write PROJ-level technical design.
- `writing-plans`, `executing`, `qa`, and `documentation` rely on its scope boundaries and project identity.

Because this starts the chain, the concept must be stable enough for downstream skills to use without re-litigating the basic feature intent. Do not leave unresolved ambiguity in the concept just because a later step exists.

## Output Contract

The concept document must provide enough product-level input for downstream skills to proceed without repeating discovery.

### Required For All Downstream Skills

- Feature intent and selected product direction.
- Primary users and concrete usage scenarios.
- Current workflow or pain.
- Scope boundaries: in scope, out of scope, later.
- Success criteria stated as product/user outcomes.
- Product-level constraints, dependencies, and risks.
- Confirmed assumptions and conscious trade-offs.
- High-level implementation success conditions.

### Required For `visual-companion` When The Feature Has UI

- Primary user job and surrounding context.
- Information shape: list/detail, form-heavy, review/approval, timeline, dashboard, wizard-like, or other high-level shape.
- Likely UI tensions that need exploration, without choosing the container.
- Mobile importance, deep-link needs, destructive-action concerns, and context-preservation needs.
- UI anti-goals or constraints from the product discussion.

### Required For `requirements-engineer`

- Users and scenarios.
- Selected direction and major behaviors.
- Scope boundaries and success criteria.
- Product-level edge cases and failure expectations.
- Constraints that PRDs must preserve.

### Required For `architecture` And Planning

- Product constraints with technical implications.
- Data ownership hints, permission hints, and external dependency hints.
- Operational risks, durability expectations, latency expectations, and existing behavior to preserve.
- Explicit non-goals so architecture and plans do not overbuild.

### Mockup-Relevant Inputs

For UI features, brainstorming may record product vocabulary, required high-level states, content examples, and existing behavior to preserve. It must not create screen lists, sitemaps, component reuse decisions, visual styling, or UI implementation handoff; those belong to `visual-companion`, `frontend-design`, and `ui-mockup`.

## Downstream Boundary

Brainstorming must produce the inputs later skills need without doing their work.

### Brainstorming Owns

- Feature intent and problem framing.
- Primary users and real usage scenarios.
- Current workflow or pain.
- Business/product success criteria.
- Scope boundaries: in scope, out of scope, later.
- Product-level constraints and dependencies.
- High-level implementation success discussion: what must be true for the later implementation to be considered successful.
- High-level risks and trade-offs.
- Whether the feature has UI and therefore needs `visual-companion`.
- Whether the feature is pure backend/API and can go directly to `requirements-engineer`.

### Brainstorming Does Not Own

- UI container decisions such as sidepanel, modal, drawer, split view, wizard, or dedicated page. That belongs to `visual-companion`.
- Visual design language, colors, typography, spacing, or style direction. That belongs to `frontend-design`.
- Screen-by-screen mockups, sitemap, detailed states, component reuse labels, or UI implementation handoff. That belongs to `ui-mockup`.
- User stories, acceptance criteria, or detailed edge-case matrices. That belongs to `requirements-engineer`.
- Technical architecture, data model design, API design, package choices, or implementation strategy. That belongs to `architecture` and later planning.
- Wave plans, tasks, tests, file ownership, or production code. That belongs to `writing-plans` and `executing`.

When a question drifts into a later skill's responsibility, capture it as a downstream input, handoff note, or open decision instead of resolving it in brainstorming.

## Checklist

Create a task for each item and complete them in order:

1. **Explore project context** - inspect docs, specs, routes, components, APIs, recent commits, and relevant agent instructions.
2. **Assess scope** - if the idea spans multiple independent subsystems, stop and decompose before detailed questioning.
3. **Collect feature-concept intake** - gather required inputs, using project discovery where possible.
4. **Research if needed** - browse only for current, niche, regulated, or unfamiliar technical/domain context.
5. **Clarifying questions** - ask one at a time until mandatory deep-dives are covered.
6. **Controlled exploration** - explore 2-4 viable directions before selecting an approach.
7. **Assumption playback** - read back every assumption and wait for confirmation/correction.
8. **Devil's-Advocate pass** - list 3-5 weaknesses, risks, or unresolved tensions and resolve them with the user.
9. **Explicit clarity confirmation** - ask exactly: "From your perspective, is everything now clear, or are there still unclear or open points?"
10. **Present feature concept** - section by section, scaled to complexity, and get approval.
11. **Allocate PROJ-X number and theme slug** - scan `specs/PROJ-*/`, pick next free integer, agree on kebab-case theme.
12. **Create PROJ folder** - `specs/PROJ-<X>-<theme>/1_brainstorm/`.
13. **Write concept doc** - `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`.
14. **Concept self-review** - fix placeholders, contradictions, ambiguity, missing deep-dives, and scope creep.
15. **User reviews written concept** - wait for approval before transition.
16. **Transition** - UI feature -> `visual-companion`; pure backend/API -> `requirements-engineer`.

## Feature Concept Intake

Collect these inputs before converging on the concept. Do not ask everything up front. Use project inspection first, then ask the user only for missing or ambiguous inputs.

### Auto-Discovered Inputs

Gather from the repository before asking:

- Existing project purpose from `README.md`, `docs/`, `specs/INDEX.md`, and current specs.
- Existing routes, screens, components, APIs, schemas, and data flows.
- Existing design or implementation constraints from `AGENTS.md`, docs, Tailwind/theme files, component registry, deployment config, and recent commits.
- Relevant platform constraints such as Vercel runtime, storage, env vars, cron, analytics, and serverless limits.
- Prior related decisions in existing PROJ folders.

Summarize discoveries briefly before asking clarifying questions.

### Required User Inputs

These must be known before the concept can be approved:

- **Feature seed:** What is the feature idea, problem, or opportunity?
- **Primary users:** Who uses this, in which concrete scenario?
- **Current workflow or pain:** What happens today, and where does it break down?
- **Success criteria:** How will we know the feature is finished and successful? Prefer observable or measurable signals.
- **Scope boundaries:** What is in scope, out of scope, and explicitly later?
- **Constraints:** Technical, data, auth, privacy, compliance, mobile/desktop, timeline, operational, or deployment constraints.

### Conditional Inputs

Ask only when relevant:

- **Data ownership:** What data is created, read, updated, deleted, imported, exported, or retained?
- **Permissions:** Which users or roles can see or change what?
- **Failure handling:** What should happen when an external service, database, upload, model call, or background task fails?
- **Migration or compatibility:** Does this affect existing users, data, APIs, URLs, saved settings, or integrations?
- **Auditability:** Do actions need logs, history, approvals, or rollback?
- **Shareability:** Do screens or objects need deep links?
- **Volume and performance:** Expected item counts, file sizes, traffic, latency, or concurrency.
- **Internationalization/timezone:** Languages, locales, currencies, date handling, or time zones.

### High-Level Implementation Success Inputs

Discuss implementation success only at the level needed to guide downstream skills:

- What would make the delivered feature feel successful to users and stakeholders?
- What must remain true about the existing product while this feature is added?
- Which constraints would make an otherwise correct implementation unacceptable?
- Which operational failures must be avoided or handled gracefully?
- Which downstream artifact needs special attention: UI shape, mockups, PRDs, architecture, wave planning, QA, or documentation?

Do not decide how to implement these points. Record them as product-level success conditions, constraints, risks, or handoff notes.

### Concept-Shaping Inputs

Use these to choose the right direction, not to inflate scope:

- **Concept emphasis:** MVP slice, UX direction, technical feasibility, scope decomposition, or risk reduction. The output remains a buildable concept either way.
- **Implementation appetite:** small tactical change, solid MVP, extensible foundation, or high-polish workflow.
- **Risk tolerance:** conservative, balanced, experimental.
- **Decision priority:** speed, correctness, UX quality, maintainability, cost, compliance, or future extensibility.

## Clarifying Questions

Mandatory deep-dives:

- **Success criteria:** Ask at least two questions unless already concrete and measurable.
- **Out-of-scope:** Ask at least two questions to define boundaries and "later".
- **Users and scenarios:** Ask at least two questions to get concrete personas and usage contexts.
- **Edge cases:** Ask at least one "what if" question per major feature area.

Prefer multiple-choice questions when helpful. Open-ended questions are fine when the user has useful context that options would bias.

If the user gives a vague answer, re-ask with concrete options. Do not advance on a vague yes.

## Controlled Exploration

Before presenting the concept, explore product-level alternatives deliberately. This prevents the first plausible idea from becoming the concept by inertia.

Choose the exploration mode from project context and user answers. Ask the user only if the right mode is genuinely ambiguous.

- **Practical options:** Generate 2-3 realistic feature approaches with trade-offs.
- **Broad exploration:** Generate several possible product shapes, then narrow.
- **Wild alternatives:** Briefly include unusual or constraint-breaking options, then extract practical lessons.
- **Progressive flow:** Start broad, cluster themes, then select a buildable direction.

Do not target 50-100 ideas. This skill exists to produce a feature concept, so exploration should be enough to reveal better directions without delaying convergence.

For UI features, exploration may identify that the next decision is about interface shape, but must not choose the detailed layout container. Capture likely UI tensions for `visual-companion` instead.

### Perspective Pivots

When the discussion is stuck or too narrow, pivot through 3-5 lenses:

- User experience
- Technical feasibility
- Existing system fit
- Data model and ownership
- Auth, permissions, security, and privacy
- Operations, support, and observability
- Edge cases and failure modes
- Cost, latency, and deployment/runtime constraints
- Future extensibility
- What is intentionally not being built

Use pivots as internal prompts, not as a long questionnaire.

## Approach Proposal

After intake and exploration, propose 2-3 approaches.

For each approach include:

- What it is
- Best fit
- Trade-offs
- Scope impact
- Main risks

Lead with your recommendation and explain why. The recommendation must account for project context, user goals, success criteria, constraints, and out-of-scope boundaries.

## Assumption Playback

Before the Devil's-Advocate pass, explicitly read back assumptions:

```markdown
I derived the following assumptions from your answers. Please confirm or correct each one:

1. ...
2. ...
3. ...
```

Wait for the user to confirm or correct each one. Corrections trigger follow-up questions, not silent re-derivation.

Separate:

- **Confirmed inputs:** stated directly by the user or discovered in project files.
- **Assumptions:** inferred from answers and needing confirmation.
- **Open questions:** still unresolved.

## Devil's-Advocate Pass

List 3-5 weaknesses, risks, or unresolved tensions in the selected direction.

Examples:

- "The success criterion says 'fast', but we have not defined a threshold. Is under 500ms the target?"
- "The out-of-scope list excludes admin tools, but support may need a manual recovery path. Is that accepted risk?"
- "Two personas may update the same object at the same time. We have not chosen conflict behavior."
- "This depends on durable background work, but the deployment target is serverless. We need a persistence strategy."

The user must resolve each item or explicitly accept it as a conscious risk.

## Explicit Clarity Confirmation

Ask exactly:

> "From your perspective, is everything now clear, or are there still unclear or open points?"

Only an unambiguous answer such as "everything is clear" or "nothing is unclear anymore" lets you proceed. Any vague or partial answer sends you back to clarification.

## Presenting The Feature Concept

Present the concept in sections scaled to complexity. Ask for approval after each section when the concept is large or nuanced.

Cover:

- Problem and goal
- Primary users and scenarios
- Current workflow or pain
- Selected direction
- Scope
- Out of scope
- Success criteria
- Key flows or behaviors
- Data and permissions, if relevant
- Error and edge-case behavior
- Constraints and dependencies
- High-level implementation success conditions
- Downstream handoff notes
- Explored alternatives and why they were not selected
- Risks and conscious trade-offs
- Testing focus

Do not over-specify implementation details. Architecture, PRDs, plans, and implementation come later.

## Concept Document

After approval, allocate the PROJ folder and write:

```text
specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md
```

Use this structure:

```markdown
# PROJ-<X> Concept - <theme>

## Status
Approved concept

## Feature Seed

## Project Context
- Existing system:
- Relevant constraints:
- Prior related specs:

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

## Error Handling And Edge Cases

## High-Level Implementation Success
- User/stakeholder success:
- Product constraints:
- Operational constraints:
- Existing behavior to preserve:
- Downstream attention needed:

## Downstream Handoff Notes
- For visual-companion:
- Mockup-relevant product inputs:
- For requirements-engineer:
- For architecture/planning:

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

The concept is the root input for the rest of the chain. Keep it product-level and decision-rich, but do not turn it into PRDs, architecture, or an implementation plan.

Commit with:

```bash
feat(PROJ-<X>): add concept for <theme>
```

## Concept Self-Review

Review the written concept before asking the user to review it:

1. **Placeholder scan:** no `TBD`, `TODO`, empty sections, or vague words standing in for decisions.
2. **Internal consistency:** selected direction, scope, users, success criteria, and risks do not contradict each other.
3. **Scope check:** the concept is focused enough for one PROJ, or it has been decomposed.
4. **Ambiguity check:** requirements cannot be interpreted in materially different ways.
5. **Deep-dive coverage:** success criteria, out-of-scope, and users/scenarios are explicitly documented.
6. **Exploration record:** rejected/deferred alternatives are captured briefly.
7. **Assumption record:** confirmed assumptions are documented; unresolved assumptions are not hidden.
8. **Output contract check:** required downstream inputs are present for `visual-companion` or `requirements-engineer`, and for architecture/planning.
9. **Downstream boundary check:** none of these have leaked into the concept:
   - UI container choice such as sidepanel, modal, drawer, wizard, split view, or dedicated page.
   - Screen list, sitemap, detailed UI states, component reuse decision, visual styling, or UI implementation handoff.
   - User stories, acceptance criteria, or detailed edge-case matrix.
   - API design, schema design, package choice, architecture decision, task plan, test plan, file ownership, or production code.
10. **Implementation success check:** high-level implementation success is documented as product constraints, risks, or handoff notes, not as technical design.

Fix issues inline. If fixing requires information not already confirmed, ask the user.

## User Review Gate

After self-review, ask the user to review the written concept:

> "Concept written and committed to `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`. Please review it and let me know if you want to make any changes before we continue."

Wait for the user's response. If they request changes, update the concept and run self-review again. Only proceed after approval.

## Transition

- If the feature has a UI component, invoke `visual-companion`.
- If the feature is pure backend/API, invoke `requirements-engineer`.
- Do NOT invoke writing-plans, architecture, executing, QA, documentation, or implementation directly from brainstorming.

## Key Principles

- Feature concept is the endpoint.
- Ask one question at a time.
- Inspect the project before asking questions the repo can answer.
- Ask, never assume.
- Vague answers are non-answers.
- Explore before converging.
- Keep exploration bounded by the goal of a buildable concept.
- Record rejected alternatives.
- YAGNI ruthlessly.
- Stop only after deep-dives are covered, assumptions are confirmed, risks are addressed, and the user says nothing important is unclear.
