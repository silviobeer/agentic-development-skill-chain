---
name: visual-companion
description: "Explore interactive UI structure before requirements. Use when a concept exists and the team needs to discuss and decide the rough shape of the interface: sidepanel vs modal vs drawer vs split view vs wizard vs dedicated page, navigation model, screen flow, and interaction container. Starts with conversational discovery questions, then produces multiple clickable low-fidelity HTML approaches grounded in the existing app, then returns to conversation for selection and iteration. Not for polished visual design, final mockups, colors/typography, or detailed acceptance criteria."
---

# Visual Companion — Interactive Layout Exploration

Turn a UI concept into **multiple rough, clickable layout approaches** so the team can decide what the interface should broadly feel like before requirements are written.

<HARD-GATE>
Do NOT write production code, define colors/typography, create final components, or write detailed acceptance criteria. This step produces disposable low-fidelity exploration artifacts only.
</HARD-GATE>

## Purpose

Bridge concept and requirements by answering: **What is the right UI shape?**

Examples:
- Sidepanel vs modal vs full page
- Drawer vs inline editor vs split view
- Wizard vs single-page form
- Sidebar navigation vs tabs vs contextual actions
- Master-detail vs list/detail pages

The output is not "the design". It is a decision aid for requirements.

## Decomposed PROJ Handling

Visual Companion normally runs for one PROJ at a time. If the concept says the seed was decomposed into sibling PROJs:

- Read the `Decomposition Context` in the concept and keep this exploration scoped to the current PROJ's user outcome.
- Mention sibling PROJs only as context, dependencies, or future navigation/entry points.
- Do not design screens or flows that belong to sibling PROJs unless the user explicitly asks for a combined UI review.
- If several sibling PROJs are tightly linked in the same UI, the shared **design language** may be handled once by `frontend-design` for the PROJ family; this skill still records the current PROJ's layout decision.
- Record any cross-PROJ UI dependency in `layout-decision.md` so `ui-mockup` and `requirements-engineer` do not accidentally absorb sibling scope.

## Required Outputs

Write all outputs to `specs/PROJ-<X>-<thema>/2_visual-companion/`:

1. `layout-exploration.html` — one interactive HTML file with 3-4 clickable layout approaches.
2. `layout-decision.md` — summary, project mode, trade-off matrix, recommendation, and open decisions.

Commit with:

```bash
docs(PROJ-<X>): explore UI layout approaches for <thema>
```

## Workflow

### 1. Read Concept And Existing UI

Read the concept doc:

```text
specs/PROJ-<X>-<thema>/1_brainstorm/PROJ-<X>-concept.md
```

Then inspect the existing app so the exploration fits what is already there:

- Routes: `src/app`, `src/pages`, router files
- Layout shells: app layouts, dashboard layouts, nav components
- Existing interaction containers: modal, dialog, drawer, sidepanel, sheet, popover, tabs, command palette, wizard/stepper
- Components: `src/components`, `src/features/*/components`, `docs/components.md`
- Design/system hints: `docs/TECHNICAL.md`, `AGENTS.md`, existing CSS/Tailwind/component conventions

Summarize the reusable patterns found in `layout-decision.md` under `Existing UI Patterns`.

If no app UI exists yet, state that clearly and choose common patterns appropriate to the domain.

Classify the project mode and document it in `layout-decision.md`:
- `greenfield` — no reusable app shell, component set, design tokens, or real screens exist yet.
- `brownfield` — existing screens/components/tokens/navigation meaningfully constrain the new feature.
- `hybrid` — some reusable structure exists, but meaningful design or component gaps remain.

Use concrete evidence, not vibes:
- Existing components: `Button`, `Dialog`, `Drawer`, `Table`, `Tabs`, form primitives, etc.
- Existing visual language: CSS variables, Tailwind theme, fonts, spacing/radius conventions.
- Existing product structure: routes, navigation, app shell, page patterns.
- Missing gaps: no overlay primitive, no data-table pattern, no mobile shell, no documented tokens.

### 2. Reflect The Idea And Discuss

Before generating artifacts, come back to the conversation with a short reflection and discovery questions.

Your message must include:
- **Idea reflection:** "I understand the feature as..."
- **Existing UI scan:** what app patterns/components/routes you found, or that no UI exists yet
- **Project mode:** `greenfield`, `brownfield`, or `hybrid`, with one-sentence reason
- **Likely UI tension:** the 1-3 layout decisions that matter most
- **Initial candidate directions:** 2-4 rough options worth exploring

Then ask targeted questions. Prefer one question at a time unless the user explicitly asks to move fast.

Question topics to choose from:
- Should the user keep surrounding context visible, or enter a focused task flow?
- Is this primarily quick operational work or deep editing/review?
- Is mobile use important for this flow?
- Is the data shape list/detail, form-heavy, review/approval, timeline, dashboard, or wizard-like?
- Should the feature feel like a small addition to an existing screen or a dedicated workspace?
- Are destructive/irreversible actions involved?
- Does the user expect shareable URLs/deep links?

Do not ask generic questions whose answers are already obvious from the concept or app scan.

Stop and wait for the user's answer when the layout direction is genuinely ambiguous. After the answer, summarize the decision axes and proceed.

### 3. Identify The UI Decision

Extract the 1-3 layout decisions that matter most. Do not enumerate every possible screen yet.

Examples:
- "Where does object detail open: sidepanel, modal, or full page?"
- "Is creation a wizard or an inline form?"
- "Does the feature belong in the existing dashboard shell or a focused workspace?"

Document assumptions from the conversation in `layout-decision.md`.

### 4. Generate 3-4 Approaches

Create distinct approaches. Prefer variants that answer the user's real uncertainty.

Common approach set:
- **Approach A — Sidepanel / Drawer:** keeps list context visible, good for inspect/edit flows.
- **Approach B — Modal / Popup:** focused short task, good for quick create/confirm flows.
- **Approach C — Dedicated Page / Full View:** good for deep editing, complex data, shareable URLs.
- **Approach D — Split View / Wizard / Inline Flow:** include only if it genuinely fits.

Each approach must include:
- Best-fit use case
- Main flow steps
- Pros
- Cons
- Fit with existing UI patterns
- Mobile/responsive concern

### 5. Build One Interactive HTML Prototype

Create:

```text
specs/PROJ-<X>-<thema>/2_visual-companion/layout-exploration.html
```

The file must be self-contained HTML/CSS/JS and runnable by opening it in a browser. No build step.

Interaction requirements:
- Tabs or segmented control to switch between approaches
- Clickable primary actions such as `Create`, `Open details`, `Edit`, `Save`, `Cancel`
- State changes that demonstrate the flow: panel opens, modal appears, wizard advances, selected row changes, etc.
- A compact "decision notes" area per approach
- At least one desktop-width frame and one mobile-width preview or responsive toggle when mobile behavior matters

Visual rules:
- Low fidelity only: neutral grays, borders, labels, placeholder content
- Use rough boxes and real layout relationships, not polished styling
- Reuse existing app vocabulary from the scan: route names, object names, component names
- Do not invent final copy, colors, typography, or branded visuals

### 6. Write Decision Summary

Create:

```text
specs/PROJ-<X>-<thema>/2_visual-companion/layout-decision.md
```

Use this structure:

```markdown
# PROJ-<X> Visual Companion — <thema>

## Existing UI Patterns
- ...

## Project Mode
- Mode: greenfield | brownfield | hybrid
- Evidence:
- Design/component gaps:

## Layout Decision To Make
- ...

## Approaches
### A. <name>
- Flow:
- Pros:
- Cons:
- Existing-fit:
- Mobile:

### B. <name>
...

## Trade-off Matrix
| Approach | Speed | Clarity | Complexity | Mobile fit | Existing fit | Risk |
|---|---:|---:|---:|---:|---:|---|

## Recommendation
<one clear recommendation with rationale>

## Shape Brief
- Primary job:
- User context:
- Information shape:
- Interaction container:
- Existing components to preserve:
- New component candidates:
- Design constraints:
- Anti-goals:

## Conversation Notes
- Questions asked:
- User answers:
- Assumptions:

## Open Decisions For User
- ...
```

### 7. Return To Conversation

After generating the HTML and decision summary, return to the conversation. Do not silently continue to the next skill.

Your response must:
- Link the generated files
- Summarize the 3-4 approaches in one line each
- State your recommendation
- Ask the user to choose, reject, or combine approaches
- Offer to iterate the same files based on feedback

Good prompt:

> "I created an interactive layout exploration at `specs/PROJ-<X>-<thema>/2_visual-companion/layout-exploration.html`. Please try the variants and tell me which direction should drive the requirements: A, B, C, or a combination."

Iterate by editing the same files. Do not create many `v2` files unless the user explicitly wants history.

### 8. Transition

After the user chooses a direction:

- Update `layout-decision.md` with `## Selected Direction`.
- Then invoke `frontend-design` if `Project Mode` is `greenfield`, or `hybrid` with meaningful design-language gaps.
- Otherwise invoke `ui-mockup` directly for `brownfield`.
- The selected layout direction is the required input for `ui-mockup`.

Do NOT invoke `requirements-engineer`, `architecture`, or implementation directly from this skill.

Do not transition until the user has explicitly selected or approved a direction after seeing the generated exploration.

## Key Principles

- **Explore alternatives, then recommend.** The skill must produce multiple approaches, not a single assumed layout.
- **Discuss before generating.** Ask the few questions that clarify the layout decision; do not skip straight to artifacts.
- **Return after generating.** The generated HTML is the start of the decision conversation, not the end of the skill.
- **Interactive beats static.** Demonstrate panels, popups, drawers, tabs, and flow transitions with clickable HTML.
- **Grounded in the app.** Existing routes, components, and navigation patterns are constraints, not afterthoughts.
- **Coarse before detailed.** Decide containers, flow, and information hierarchy; leave detailed UI to `ui-mockup` and design language to `frontend-design`.
- **Decision-oriented.** The artifact should help the user pick a direction quickly.

## What This Step Does NOT Do

| Concern | Handled by |
|---|---|
| Colors, typography, visual identity | `frontend-design` |
| Detailed HTML mockups with polished styling | `ui-mockup` |
| User stories and acceptance criteria | `requirements-engineer` |
| Technical architecture | `architecture` |
| Production implementation | `executing` |
