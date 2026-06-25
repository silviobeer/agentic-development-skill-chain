---
name: requirements-engineer
description: "Create detailed feature PRDs with user stories, acceptance criteria, and edge cases after Visual Companion, optional Frontend Design, and UI Mockup. Use when: (1) an approved concept and optional UI mockups need to become structured PRDs, (2) user stories and acceptance criteria must be written, (3) edge cases must be identified. Not for: UI mockups, writing code, technical design, or debugging."
---

# Requirements Engineer

Turn the approved concept into structured Product Requirements Documents. Focus on what the feature must do, not how it will be implemented.

Never write code or technical architecture in this skill. Architecture and implementation happen later in the chain.

## PROJ vs. PRD

- **PROJ-X** is the initiative or feature theme, for example `PROJ-1-auth`. Brainstorming assigns it and creates the folder.
- **PRD-Y** is one testable, deployable feature inside the PROJ. Number PRDs from 1 within each PROJ.

## Feature Granularity

Each PRD should describe one testable, deployable unit.

Split into a separate PRD when:

1. It can be tested independently.
2. It can be deployed independently.
3. It serves a different user role.
4. It is a separate UI component, screen, API capability, or workflow.

Prefer several focused files inside the same PROJ over one large PRD:

```text
specs/PROJ-1-auth/3_PRDs/
  PROJ-1-PRD-1-user-signup.md
  PROJ-1-PRD-2-login.md
  PROJ-1-PRD-3-password-reset.md
```

Document dependencies between PRDs, including cross-PROJ dependencies, inside each PRD.

## Delivery Track

Detect how this PROJ will be delivered before writing PRDs. The concept's `Handoff Readiness` section (written by `concept-sync`) sets `Delivery track`; if it is absent, infer from context and confirm with the user.

- **Full chain (in-repo build):** Steps 3–7 follow in this repo. Write PRDs normally, including the `UI Implementation Notes` section with component reuse and file-path hints.
- **Discovery / Linear handoff:** There is no codebase here. You are producing a developer handoff that goes to Linear (https://linear.app). The developer who picks it up owns architecture and implementation. In this mode:
  - Write the same PRDs (user stories, acceptance criteria, edge cases) — these are the contract.
  - Do **not** invent in-repo file paths or component locations. Replace `UI Implementation Notes` component-path hints with mockup references and design intent only.
  - Additionally produce a paste-ready `linear-import.md` (see the Linear handoff workflow step).
  - Do **not** recommend `architecture` (3); the chain stops at Step 2 for this PROJ.

## Decomposed PROJ Handling

Requirements run one PROJ at a time. If the concept contains `Decomposition Context`:

- Write PRDs only for the current PROJ.
- Do not absorb sibling PROJ scope into user stories.
- Document cross-PROJ dependencies explicitly under `## Dependencies`.
- If a sibling PROJ is a blocker, do not write stories that assume its behavior except as a dependency or precondition.
- A shared design language from a sibling PROJ may be referenced, but it does not expand the current product scope.

## Input

Read these inputs:

1. Concept: `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`
2. UI mockups: `specs/PROJ-<X>-<theme>/5_mockups/*.html`
3. Sitemap: `specs/PROJ-<X>-<theme>/5_mockups/sitemap.html`
4. UI implementation handoff: `specs/PROJ-<X>-<theme>/5_mockups/implementation-handoff.md`
5. Optional Visual Companion decision: `specs/PROJ-<X>-<theme>/2_visual-companion/layout-decision.md`
6. Optional design language: `specs/PROJ-<X>-<theme>/4_design/design-language.md`
7. Optional shared sibling design language referenced by the concept, layout decision, or mockup handoff

For UI features, mockups and `implementation-handoff.md` are required inputs. They define screens, flows, states, component reuse, new component candidates, design tokens, the interaction contract, and implementation tolerance.

If a UI feature has no mockups, stop and run `visual-companion` -> optional `frontend-design` -> `ui-mockup` first. Pure backend/API features may proceed directly from the concept.

## Workflow

### 1. Check Existing PRDs

Before creating a PRD, inspect `specs/PROJ-<X>-<theme>/3_PRDs/`.

Use the next available `PRD-Y` number inside the PROJ, starting at 1 and avoiding gaps where practical. Do not duplicate existing PRDs.

### 2. Understand The Feature

For UI features, read mockups and sitemap first:

- Which screens exist?
- Which user flows are clickable or linked?
- Which states are visible?
- Which assumptions or source references are marked?
- Which `Project Mode` applies?
- Which components and tokens must be reused?
- Which new component candidates did the user accept?
- Which interactions are implementation contract vs. demo-only?

Ask the user focused questions only when needed:

- Who are the primary users?
- What is MVP scope vs. nice-to-have?
- What constraints exist?

Ask one question at a time and follow up based on the answer.

### 3. Clarify Edge Cases

Identify and prioritize edge cases:

- Unexpected inputs
- Empty or missing data
- Permission and role boundaries
- Failure and retry behavior
- Security-relevant scenarios
- Limits, quotas, and performance-sensitive paths

### 4. Write PRDs

Save PRDs under:

```text
specs/PROJ-<X>-<theme>/3_PRDs/PROJ-<X>-PRD-<Y>-<short-description>.md
```

Use kebab-case for `<short-description>`.

Template:

```markdown
# PROJ-<X>-PRD-<Y>: Feature Name

## Status: Planned

## User Stories

### US-1: As a [user type], I want [action] so that [goal]
**Given** [starting condition]
**When** [action]
**Then** [expected result]
**And** [additional expected result, if needed]

**Acceptance Criteria:**
- [ ] AC-1: Testable criterion derived from the Then/And clauses
- [ ] AC-2: Another testable criterion for this story

### US-2: As a [user type], I want ...
**Given** ...
**When** ...
**Then** ...

**Acceptance Criteria:**
- [ ] AC-3: ...

## Edge Cases
- What happens when...?

## Dependencies
- Requires: PROJ-<X>-PRD-<Y>
- Cross-PROJ dependency: PROJ-<A>-PRD-<B>

## Technical Requirements
- Performance, security, compatibility, or operational constraints.

## UI Implementation Notes
- Project mode:
- Reuse:
- New component candidates:
- Design tokens:
- Interaction contract:
- Implementation tolerance:
```

Each user story owns its own acceptance criteria. Do not create one global acceptance-criteria section. Derive ACs directly from the story's Given/When/Then/And clauses and make them testable.

### 5. Produce The Linear Handoff (Discovery Track Only)

Skip this step for the full-chain track. For the discovery / Linear handoff track, create:

```text
specs/PROJ-<X>-<theme>/3_PRDs/linear-import.md
```

This file is structured so each PRD becomes a Linear issue and each user story becomes a checklist item or sub-issue. Keep it paste-ready and free of in-repo implementation detail.

```markdown
# Linear Import — PROJ-<X> <theme>

> One project/epic in Linear. Each PRD below is one issue. Copy each block into a new Linear issue.

## Issue: PROJ-<X>-PRD-<Y> — <feature name>
**Description**
<short feature summary from the concept>

**Mockups:** `specs/PROJ-<X>-<theme>/5_mockups/<file>.html` (attach exported images/PDF in Linear)

**User stories & acceptance criteria**
- [ ] US-1: As a <user>, I want <action> so that <goal>
  - AC-1: <testable criterion>
  - AC-2: <testable criterion>
- [ ] US-2: ...

**Edge cases**
- <edge case>

**Dependencies**
- <other PRD / external dependency>

**Design intent**
- Fidelity: wireframe greyscale | adopt existing design system
- Notes: <visual/interaction intent the developer must preserve>
```

Tell the user the developer owns architecture and implementation in Linear, and that the mockups should be attached to each issue (export HTML to images or PDF before import).

### 6. Review With The User

Ask the user to review the PRDs. If changes are requested, update the PRDs and present them again.

Also ask the user to review the PRD artifacts with a different model before approval, for example GPT reviewing Claude output or Claude reviewing GPT output. This second-model review should focus on missing user stories, weak acceptance criteria, ambiguous edge cases, and scope drift.

### 7. Handoff

- **Full chain:** recommend `architecture` (3) for PROJ-level technical design. For UI features, the mockups and implementation handoff remain visual references for architecture.
- **Discovery / Linear handoff:** do not recommend `architecture`. For a quick handoff, point the user to `3_PRDs/linear-import.md` and remind them to attach exported mockups to each Linear issue. If the work goes to people outside this repo (an external UI/UX expert, an external dev team) and a single standalone deliverable is wanted, recommend `handoff-package` (2b) to assemble a self-contained, zippable package. The chain ends here for this PROJ.

## Completion Checklist

- [ ] Existing PRDs checked for duplicates and next PRD number
- [ ] Necessary user questions answered
- [ ] UI mockups and sitemap read for UI features
- [ ] `implementation-handoff.md` read for UI features
- [ ] At least 3-5 user stories defined where feature size warrants it
- [ ] Every user story has its own acceptance criteria
- [ ] At least 3-5 edge cases documented where feature size warrants it
- [ ] PRD ID assigned and file saved in the correct folder
- [ ] Delivery track determined (full chain vs. discovery / Linear handoff)
- [ ] `linear-import.md` produced for the discovery track
- [ ] User reviewed and approved the PRD

## Git Commit Format

```text
feat(PROJ-<X>-PRD-<Y>): Add PRD for <feature-name>
```

Git is optional on the discovery track. If the workspace is not a git repository, skip the commit; the PRD files and `linear-import.md` are the durable artifacts.
