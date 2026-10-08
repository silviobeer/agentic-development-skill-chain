---
name: prototyping
description: "Create component-based or standalone HTML mockups, a visual sitemap, and a UI implementation handoff before requirements. Use after visual-companion and optional frontend-design when: (1) UI flows need to be visualized before requirements and architecture, (2) a page/screen sitemap is needed, (3) stakeholders need visual feedback before user stories are finalized. Not for: requirements, component libraries, technical architecture, or production UI code."
---

# Prototyping: Mockups, Sitemap And Findings

Create component-based or standalone HTML mockups and a visual sitemap from the concept and the approved Visual Companion decision. This skill is visual and structural only: no technical architecture and no acceptance criteria.

For UI features, this skill is required before `requirements-engineer`. Pure backend/API features skip it.

Also create a compact `implementation-handoff.md` so requirements, architecture, planning, and execution can consume the visual decision without interpreting the mockup sources directly.

## Decomposed PROJ Handling

Work one PROJ at a time. If the concept contains `Decomposition Context`:

- Build mockups and sitemap only for the current PROJ.
- Mark sibling PROJs only as context, navigation, dependencies, or future scope.
- Do not design screens or states for sibling PROJs unless the user explicitly asks for a combined UI review.
- If `frontend-design` created a shared design language for the PROJ family, use that canonical file even when it lives in a sibling PROJ.
- If the current PROJ needs a local variation, read or create `1c_design/design-delta.md` and document it in the implementation handoff.

## Principles

- **Reuse:** Import existing components, patterns, tokens, styles, and the app shell when a usable app runtime exists. Mark new UI pieces as candidates.
- **Lightweight:** Reuse the existing stack and preview tooling; no new dependencies, per-PROJ package installation, or mockup platform.
- **Interactive when useful:** Demonstrate navigation, overlays, forms, and state changes with small local fixtures, not production business logic.
- **Question-driven:** Name the open question each mockup round must answer (e.g. "Does the review state fit in the list row?") before building or iterating, and record the answer as a finding. Mockups are disposable decision aids: record what was learned, never port mockup code into production.
- **Show states:** Include normal, empty, loading, error, and success states where relevant.
- **Review annotations:** Put component reuse and source labels in a separate review area, not inside product buttons, fields, or other product copy.

## Execution Modes

Choose and announce the execution mode separately from visual fidelity:

- **Components (default with a usable app runtime):** Keep mockup screens, fixtures, and simulated interactions in `specs/PROJ-<X>-<theme>/1d_prototypes/`, using the existing stack's source format (not necessarily React). Import real components and their styles/tokens. Reuse required UI providers, but do not mount providers or shells that trigger real authentication, data fetching, or writes; use existing presentation components and fixture seams instead.
- **Standalone HTML (without a usable app runtime):** One self-contained HTML file per screen, inline CSS and small vanilla JavaScript, no external dependencies or build step. Reproduce documented visual patterns and label intended component reuse. This includes discovery with screenshots/design references but no source code.

Inspect the existing start commands, routing, preview setup, imports, and provider requirements before choosing. Use an existing dev preview or Storybook when suitable; do not introduce Storybook. Reuse a running project dev server when available, otherwise start it with the existing project command and confirm the actual local URL. Never stop or replace a server owned by someone else.

Keep only framework-required development entrypoints and minimal integration configuration outside the PROJ folder. For example, a development route at `/dev/mockups/proj-42` can import a screen from `1d_prototypes/`. Use the framework's development-only mechanism and verify the mockup entry is inaccessible in production; hiding a navigation link is insufficient. Check imports, styles, and refresh/deep links through the real preview. If the toolchain excludes the PROJ folder, first try the smallest supported source/include or filesystem-access configuration change. If importing from that location still requires a second runtime or broad refactor, keep the sources in the PROJ folder and use the documented HTML fallback below; do not relocate them into production source directories.

Do not scaffold a second app or broadly refactor production components to make a mockup work. Diagnose startup failures and make bounded fixes within the existing preview setup. If no usable runtime remains, or component isolation/source placement requires a broad refactor, announce standalone HTML fallback and record the specific blocker, attempted remedy, and approximated components in the handoff. The fallback permits mockup review and subsequent requirements work, but does not count as a verified component preview. Existing HTML mockups need no automatic conversion.

## Fidelity Modes

Pick the fidelity from the project mode and design references. State the chosen mode to the user before building.

- **Wireframe (greyscale):** Default for greenfield projects with no design system, especially when a UI/UX expert takes over the visual design later. Use a neutral greyscale palette, very small border radii (about 2–4px), no brand colors, no decorative imagery. Communicate structure, hierarchy, flows, and states — not visual identity. This keeps mockups cheap to change during iteration and avoids implying final styling.
- **Design-system:** Use when an existing design system is present (brownfield) or when `frontend-design` produced a `design-language.md`. Adopt the existing or defined tokens, colors, typography, spacing, and radii so the mockups read as the real product.
- **Hybrid:** Apply the existing design system to known areas and fall back to greyscale wireframe for the documented gaps.

If `1c_frontend-design` was skipped and no existing component styling or design reference establishes a visual identity, default to **Wireframe (greyscale)**. In a greenfield scaffold with styled real components, preserve those components and select **Design-system** fidelity (or **Hybrid** for gaps); do not recolor them solely to force wireframe fidelity. With unstyled primitives, component execution and greyscale wireframe fidelity can coexist.

## Input

Read these inputs:

1. Concept: `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`
2. Visual Companion decision: `specs/PROJ-<X>-<theme>/1b_visual-companion/layout-decision.md`
3. Visual Companion prototype: `specs/PROJ-<X>-<theme>/1b_visual-companion/layout-exploration.html`
4. Optional design language: `specs/PROJ-<X>-<theme>/1c_design/design-language.md` or a canonical sibling design language that lists the current PROJ under `Applies To`
5. Optional design delta: `specs/PROJ-<X>-<theme>/1c_design/design-delta.md`
6. Optional brownfield as-is reference (discovery track): `specs/PROJ-<X>-<theme>/0_context/existing-state.md` and `0_context/references/`

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

- If `1c_design/design-language.md` exists, use it as the primary design reference.
- If the concept or layout decision references a canonical sibling design language, load it too and apply only local `design-delta.md` differences.
- Check `docs/DESIGN-SYSTEM.md` (the curated design system baseline). If present, reuse its tokens, scales, patterns, and do/don't rules, and read `docs/components.md` for the component inventory.
- For composed layouts — form, empty/loading/error state, page shell — open the showcase (`/dev/components#pattern-<name>`, or `1c_design/component-showcase.html` before the scaffold) and reuse the actual pattern in component mode, or reproduce it in standalone HTML mode. Do not invent a layout that a pattern already fixes; that is how two screens end up with two different forms.

If no design reference exists, scan:

- `tailwind.config.*`
- CSS custom properties such as `--color-*` and `--font-*`
- `globals.css` or `theme.css`
- Existing HTML/CSS files

On the **discovery track there is no codebase to scan**. Use `0_context/existing-state.md` and the screenshots/links in `0_context/references/` as the design source instead: derive colors, typography, spacing, radii, and component patterns from the captured design system. This is the design-system fidelity input when there are no config files.

If style evidence exists (config, design language, or captured existing state), reuse it in **design-system mode**. Otherwise, for greenfield discovery, use **Wireframe (greyscale)** rather than inventing a visual identity.

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

In a separate review area, label important mockup elements:

| Screen element | Review annotation |
|----------------|-------------------|
| Save action | `Reuse: Button` |
| Delete confirmation | `Reuse: Dialog` |
| Orders table | `Reuse: DataTable` |
| Batch actions | `New candidate: BulkActionBar` |

Do not silently invent UI pieces. If no existing component fits, mark `New candidate:` and briefly explain why.

**Design system excursion.** In design-system mode (`docs/DESIGN-SYSTEM.md` exists, or a real component library is in use), a `New candidate:` is not a mockup problem — it is a gap in the design system. Do not solve it with one-off CSS in the mockup. Instead:

1. Re-check `docs/components.md`: can an existing component cover it as a new **variant** (size, tone, state)? Variant beats new component.
2. Ask the user to confirm the gap and the choice (variant vs. new component).
3. Run the extension procedure from `1c_frontend-design` → *Extending The Design System* for that one piece: define it, implement it in the chosen stack, register it in `docs/components.md`, and add its showcase section under `id="<kebab-name>"`.
4. Then use it in the mockup by its registered name.

Keep the excursion narrow: one component, no revisiting of tokens or unrelated catalog entries. In **wireframe (greyscale)** mode there is no catalog yet — keep marking candidates and let `1c_frontend-design` or `5_executing` build them later.

Detect the app shell:

- Header/topbar: position, height, background color, breadcrumb structure
- Sidebar: width, color, navigation items, active state
- Main content area: padding, scrolling, max width

If an app shell exists, use its presentation layout for every applicable mockup (real imports in component mode, a static approximation in HTML mode). If no shell exists, for example a landing or login page, mock up the screen without a shell.

### 2. Create The Sitemap

Create `specs/PROJ-<X>-<theme>/1d_prototypes/sitemap.html`.

The sitemap must show:

- All pages/screens as boxes
- Parent-child hierarchy
- Navigation flows with arrows
- User flows with visual grouping
- Role mapping for pages where relevant

Use plain HTML/CSS boxes and links. Each sitemap box links to its HTML screen file or documented local component-preview URL and identifies the corresponding source file. Include the preview start instructions for component mode; keep the sitemap itself readable without the server.

### 3. Create Screen Mockups

Create the screen sources in `specs/PROJ-<X>-<theme>/1d_prototypes/` using the selected execution mode. Reuse shared compositions rather than duplicating an app shell per screen.

Each mockup includes:

- App shell when detected: header, sidebar, and content area
- Mockup header: page name, PROJ reference, and link back to the sitemap
- Navigation links to connected mockup pages
- Main content with placeholder copy, images, forms, and data
- Component labels for important UI elements in the separate review area
- Relevant simulated interactions using the existing stack, or vanilla JS in HTML mode
- State sections for `[Normal State]`, `[Empty State]`, `[Loading State]`, and `[Error State]`
- Source reference labels for concept sections, Visual Companion decisions, or mockup assumptions

Do not add acceptance-criteria labels; requirements are written after this skill.

Interaction rules:

- In standalone HTML mode, use only vanilla JS inside the HTML file.
- Demonstrate behavior, not final implementation.
- No persistence or real backend/API calls, including indirect calls from imported components or providers. Use local fixtures and local state; the existing app build is allowed in component mode.
- Link multi-screen flows. Simulate overlays or panels in-place when they are part of the selected Visual Companion direction.

Code minimalism (HTML-specific primitives below apply only to standalone HTML mode; component mode reuses existing components and framework idioms):

- Use a few reusable primitives such as `.shell`, `.panel`, `.toolbar`, `.button`, `.table`, `.state`, and `.overlay`.
- Use `data-*` attributes for interactions, for example `data-open="trend-panel"`.
- Use one central JS handler for common actions: open/close overlay, switch tab, next/previous step, select row.
- Avoid duplicated markup. If screens share a structure, reuse it with different labels and placeholders.
- Keep sample data small: two or three rows/cards are enough.
- Avoid long resets or utility-class lists.

Before writing, ask yourself: can this mockup be expressed with fewer reusable primitives?

### 4. Review And Iterate With Stakeholders

Open the mockups in a browser, verify the linked screens and relevant states/interactions, and ask the user to review:

- Is the page structure correct?
- Are screens or flows missing?
- Do the states fit?

Stakeholders typically iterate here by prompting changes directly into the mockups until everyone agrees. Treat this as the primary working loop, not a single pass. Apply requested changes, present the updated mockups, and repeat until the user signals agreement.

**Track every change** so the agreed result can later flow back into the concept. Maintain `specs/PROJ-<X>-<theme>/1d_prototypes/iteration-log.md` and append an entry per iteration round:

```markdown
# Mockup Iteration Log — PROJ-<X> <theme>

## Iteration <N> — <date>
- Question: <what this round had to answer>
- Finding: <the answer and deciding reason>
- Change: <what changed in the mockup>
- Driver: <stakeholder feedback | own decision | open question resolved>
- Affects concept: yes (scope) | yes (behavior) | no (presentation-only)
- Screen(s): <which mockup files>
```

Classify each change's `Affects concept` field honestly: only scope or behavior changes need to flow back into the concept later; presentation-only tweaks stay in the mockups. This log is the input to `concept-sync` (1e).

Do not edit the concept doc from this skill. Capture changes in the log; reconciliation happens in `concept-sync`.

For external handoff of component mockups, capture the approved screens and relevant states under `1d_prototypes/screenshots/` and describe their flows in the implementation handoff. Map captures to screens/states and refresh affected captures after iterations. If browser capture is unavailable, record the missing evidence; do not claim the external package is ready. Do not write a second HTML implementation for export. Only `handoff-package` creates a new dated package from these source artifacts.

### 5. Create The Implementation Handoff

Create:

```text
specs/PROJ-<X>-<theme>/1d_prototypes/implementation-handoff.md
```

Required structure:

```markdown
# PROJ-<X> UI Implementation Handoff — <theme>

## Project Mode
greenfield | brownfield | hybrid

## Mockup Runtime
- Execution mode: components | standalone-html
- Start command and working directory: <existing project command, or not required for standalone HTML>
- Local preview URL: <verified URL, or not applicable>
- Development entrypoints/configuration outside the PROJ folder: <paths and purpose, or none>
- Development-only verification: <check and result, or not applicable>
- Runtime blockers / fallback reason: <details, or none>

## Screen References
| Screen / state | Source file | Preview URL or HTML file | Screenshot (external component handoff) |
|----------------|-------------|--------------------------|----------------------------------------|
| <name> | <path> | <location> | <path, or not required> |

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
- Existing app components and design tokens take precedence over standalone mockup approximations: yes

## Flow Descriptions
For each reviewed flow, describe the starting screen/state, user action, resulting screen/state, and simulated outcome. Link the corresponding Screen References entries and, for external component handoff, screenshots so readers can follow the flow offline.

## Interaction Contract
- Interaction:
- Required states:
- Responsive/mobile behavior:

## Implementation Tolerance
- Mockups define the approved interface structure and interactions; importing real components does not make simulated business behavior production-ready.
- Existing app components and design tokens take precedence over standalone mockup approximations.
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
- Where mockup differences are allowed; mockup code does not replace production implementation or tests
- How to start and locate every screen, and which behavior is simulated

### 6. Final Review

Present `sitemap.html`, the screen mockups, and `implementation-handoff.md` together. Ask the user:

- Is the component reuse list correct?
- Are the new component candidates accepted?
- Are demo-only parts correctly separated?

If changes are requested, update mockups, handoff, and any affected external-handoff screenshots together. Verify the captures still represent the final approved screens/states before declaring the handoff ready.

### 7. Handoff

After approval:

- If the mockups were iterated and the concept may have drifted (any `iteration-log.md` entry with `Affects concept: yes`), recommend `concept-sync` (1e) next so the agreed changes flow back into the concept before requirements.
- If nothing affected the concept, recommend `requirements-engineer` (2) directly.

Either way, the mockups are required input for user stories, acceptance criteria, and edge cases.

## Completion Checklist

- [ ] Design reference loaded when available
- [ ] Component registry and existing components scanned
- [ ] Important UI elements labeled with `Reuse:` or `New candidate:`
- [ ] App shell detected and embedded where applicable
- [ ] Sitemap created with all pages and flows
- [ ] Execution mode chosen and justified; screen sources kept in the PROJ folder
- [ ] Component preview verified in the browser and development entry inaccessible in production, or standalone HTML verified
- [ ] Mockup created for each screen
- [ ] Mockups linked to each other
- [ ] Relevant interactions simulated locally without real backend calls or persistence
- [ ] Real components reused in component mode; reusable HTML/CSS/JS primitives used in standalone mode
- [ ] Empty, loading, and error states included
- [ ] Source references included in mockups
- [ ] Fidelity mode chosen and stated (wireframe greyscale / design-system / hybrid)
- [ ] `iteration-log.md` maintained across iteration rounds with concept-impact classified
- [ ] `implementation-handoff.md` includes runtime details and screen/source references
- [ ] For external component handoff, current screenshots and flow descriptions are available
- [ ] User reviewed and approved mockups and handoff
- [ ] Next step recommended: `concept-sync` (1e) if concept drifted, else `requirements-engineer` (2)

## Git Commit Format

```text
docs(PROJ-<X>): Add UI mockups and sitemap for <theme>
```

Git is optional on the discovery track. If the workspace is not a git repository, skip the commit; the mockup files and `iteration-log.md` are the durable artifacts.

## Legacy Folder Layout

PROJ folders created before the layout rename use different subfolder
names. Mapping, old → current:

`2_visual-companion/` → `1b_visual-companion/` · `4_design/` → `1c_design/` ·
`5_mockups/`, `1d_prototypes/` → `1d_prototypes/` · `3_PRDs/` → `2_PRDs/` ·
`8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` ·
`7_progress/` → `5_progress/`

If an expected folder is missing but its legacy twin exists, **read from the
legacy one and keep writing where the existing files already are**. Never
create a second folder next to it — a split PROJ is worse than an old name.
Say it once, then continue either way:

> "This PROJ uses the old folder layout (`<old>`). Rename the folders to the
> current names, or continue with the existing layout?"

Renaming is a `git mv` per folder plus a search for the old paths in the
PROJ's own documents. It is never a precondition for this skill.
