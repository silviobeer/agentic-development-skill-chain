---
name: ui-mockup
description: "Create lightweight HTML mockups, a visual sitemap, and a UI implementation handoff before requirements. Use after visual-companion and optional frontend-design when: (1) UI flows need to be visualized before requirements and architecture, (2) a page/screen sitemap is needed, (3) stakeholders need visual feedback before user stories are finalized. Not for: requirements, component libraries, technical architecture, or production UI code."
---

# UI Mockup And Sitemap Generator

Create lightweight HTML mockups and a visual sitemap from the concept and the approved Visual Companion decision. This skill is visual and structural only: no technical architecture and no acceptance criteria.

For UI features, this skill is required before `requirements-engineer`. Pure backend/API features skip it.

Also create a compact `implementation-handoff.md` so requirements, architecture, planning, and execution can consume the visual decision without interpreting the HTML mockups directly.

## Decomposed PROJ Handling

Work one PROJ at a time. If the concept contains `Decomposition Context`:

- Build mockups and sitemap only for the current PROJ.
- Mark sibling PROJs only as context, navigation, dependencies, or future scope.
- Do not design screens or states for sibling PROJs unless the user explicitly asks for a combined UI review.
- If `frontend-design` created a shared design language for the PROJ family, use that canonical file even when it lives in a sibling PROJ.
- If the current PROJ needs a local variation, read or create `4_design/design-delta.md` and document it in the implementation handoff.

## Principles

- **Lightweight:** Single HTML files, inline CSS, small vanilla JavaScript, no external dependencies.
- **DRY mockups:** Reuse CSS classes, HTML patterns, and small JS helpers instead of writing one-off code per screen.
- **Interactive when useful:** Clickable flows, tabs, side panels, modals, drawers, wizard steps, and state changes are encouraged when they clarify the UI.
- **Simple:** No frameworks, no build step, no complex animation.
- **Design-aware:** If an existing UI exists, scan and reuse colors, fonts, spacing, CSS variables, Tailwind config, and design tokens.
- **Component-aware:** Prefer existing components and patterns; mark new UI pieces as candidates.
- **Component-near, not pixel-perfect:** Approximate existing React components structurally and visually. Label intended reuse clearly.
- **Show states:** Include normal, empty, loading, error, and success states where relevant.

## Input

Read these inputs:

1. Concept: `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`
2. Visual Companion decision: `specs/PROJ-<X>-<theme>/2_visual-companion/layout-decision.md`
3. Visual Companion prototype: `specs/PROJ-<X>-<theme>/2_visual-companion/layout-exploration.html`
4. Optional design language: `specs/PROJ-<X>-<theme>/4_design/design-language.md` or a canonical sibling design language that lists the current PROJ under `Applies To`
5. Optional design delta: `specs/PROJ-<X>-<theme>/4_design/design-delta.md`

The selected direction in `layout-decision.md` is binding. Refine it into concrete screens and states. Do not invent alternate layout containers unless the user explicitly asks.

Read these sections especially:

- `Project Mode` (`greenfield`, `brownfield`, `hybrid`)
- `Selected Direction`
- `Shape Brief`
- `Existing UI Patterns`
- `Design/component gaps`

## Workflow

### 1. Detect Design System, Components, And App Shell

Load design references:

- If `4_design/design-language.md` exists, use it as the primary design reference.
- If the concept or layout decision references a canonical sibling design language, load it too and apply only local `design-delta.md` differences.
- Check `.codex/skills/references/design-system.md` first in the project, then globally under `~/.codex/skills/references/`. If present, reuse its colors, typography, spacing, component patterns, and do/don't rules.

If no design reference exists, scan:

- `tailwind.config.*`
- CSS custom properties such as `--color-*` and `--font-*`
- `globals.css` or `theme.css`
- Existing HTML/CSS files

If style evidence exists, reuse it. Otherwise use minimal clean defaults: system fonts and neutral colors.

Detect existing components before building mockups:

- `docs/components.md`
- `src/components/**`
- `src/features/*/components/**`
- UI library hints in `package.json` such as shadcn, Radix, MUI, Chakra, or Headless UI
- Existing dialog, modal, drawer, table, form, button, card, badge, tabs, and command components

Keep a short internal component map:

```markdown
Reuse candidates:
- Button: `src/components/ui/button.tsx`
- Dialog: `src/components/ui/dialog.tsx`
- DataTable: `src/components/data-table.tsx`

New component candidates:
- BulkActionBar — no matching batch-action component found
```

Label important mockup elements:

- `[Reuse: Button] Save`
- `[Reuse: Dialog] Confirm delete`
- `[Reuse: DataTable] Orders`
- `[New candidate: BulkActionBar]`

Do not silently invent UI pieces. If no existing component fits, mark `New candidate:` and briefly explain why.

Detect the app shell:

- Header/topbar: position, height, background color, breadcrumb structure
- Sidebar: width, color, navigation items, active state
- Main content area: padding, scrolling, max width

If an app shell exists, embed every mockup inside it. If no shell exists, for example a landing or login page, mock up the screen without a shell.

### 2. Create The Sitemap

Create `specs/PROJ-<X>-<theme>/5_mockups/sitemap.html`.

The sitemap must show:

- All pages/screens as boxes
- Parent-child hierarchy
- Navigation flows with arrows
- User flows with visual grouping
- Role mapping for pages where relevant

Use plain HTML/CSS boxes and links. Each sitemap box links to its mockup file.

### 3. Create Screen Mockups

Create one HTML file per screen in `specs/PROJ-<X>-<theme>/5_mockups/`.

Each mockup includes:

- App shell when detected: static header, sidebar, and content area
- Mockup header: page name, PROJ reference, and link back to the sitemap
- Navigation links to connected mockup pages
- Main content with placeholder copy, images, forms, and data
- Component labels for important UI elements
- Relevant vanilla-JS interactions
- State sections for `[Normal State]`, `[Empty State]`, `[Loading State]`, and `[Error State]`
- Source reference labels for concept sections, Visual Companion decisions, or mockup assumptions

Do not add acceptance-criteria labels; requirements are written after this skill.

Interaction rules:

- Use only vanilla JS inside the HTML file.
- Demonstrate behavior, not final implementation.
- No persistence, API calls, or build step.
- Link multi-screen flows. Simulate overlays or panels in-place when they are part of the selected Visual Companion direction.

Code minimalism:

- Use a few reusable primitives such as `.shell`, `.panel`, `.toolbar`, `.button`, `.table`, `.state`, and `.overlay`.
- Use `data-*` attributes for interactions, for example `data-open="trend-panel"`.
- Use one central JS handler for common actions: open/close overlay, switch tab, next/previous step, select row.
- Avoid duplicated markup. If screens share a structure, reuse it with different labels and placeholders.
- Keep sample data small: two or three rows/cards are enough.
- Avoid long resets or utility-class lists.

Before writing, ask yourself: can this mockup be expressed with fewer reusable primitives?

### 4. Review With The User

Open the mockups in a browser and ask the user to review:

- Is the page structure correct?
- Are screens or flows missing?
- Do the states fit?

If changes are requested, update the mockups and present them again.

### 5. Create The Implementation Handoff

Create:

```text
specs/PROJ-<X>-<theme>/5_mockups/implementation-handoff.md
```

Required structure:

```markdown
# PROJ-<X> UI Implementation Handoff — <theme>

## Project Mode
greenfield | brownfield | hybrid

## Source References
- Concept:
- Visual Companion decision:
- Mockups:
- Design language:

## Selected UI Direction
[One paragraph describing the selected container/model.]

## Reuse
- Component: `path/to/component.tsx` — intended use

## New Component Candidates
- ComponentName — why no existing component fits

## Design Tokens And Styling
- Use:
- Avoid:
- Existing app design takes precedence over exact HTML mockup CSS: yes

## Interaction Contract
- Interaction:
- Required states:
- Responsive/mobile behavior:

## Implementation Tolerance
- Mockups are structural, not pixel-perfect.
- Existing React components and design tokens take precedence over mockup CSS.
- Preserve the selected layout direction and interaction contract unless the user approves a change.

## Demo-Only In Mockup
- [Things shown only to explain the flow and not required for implementation.]

## Open UI Risks
- [Ambiguities or component gaps Architecture/Writing Plans should account for.]
```

The handoff must make clear:

- Which existing components must be reused
- Which new components may be built
- Which tokens, fonts, and colors are binding
- Which interactions must be implemented
- Where HTML mockup differences are allowed

### 6. Final Review

Present `sitemap.html`, the screen mockups, and `implementation-handoff.md` together. Ask the user:

- Is the component reuse list correct?
- Are the new component candidates accepted?
- Are demo-only parts correctly separated?

If changes are requested, update mockups and handoff together.

### 7. Handoff

After approval, recommend `requirements-engineer` (2). The mockups are now required input for user stories, acceptance criteria, and edge cases.

## Completion Checklist

- [ ] Design reference loaded when available
- [ ] Component registry and existing components scanned
- [ ] Important UI elements labeled with `Reuse:` or `New candidate:`
- [ ] App shell detected and embedded where applicable
- [ ] Sitemap created with all pages and flows
- [ ] Mockup created for each screen
- [ ] Mockups linked to each other
- [ ] Relevant interactions simulated with vanilla JS
- [ ] Reusable HTML/CSS/JS primitives used
- [ ] Empty, loading, and error states included
- [ ] Source references included in mockups
- [ ] `implementation-handoff.md` created
- [ ] User reviewed and approved mockups and handoff

## Git Commit Format

```text
docs(PROJ-<X>): Add UI mockups and sitemap for <theme>
```
