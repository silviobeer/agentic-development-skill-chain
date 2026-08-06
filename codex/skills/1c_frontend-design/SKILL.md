---
name: frontend-design
description: "Define the design system — visual design language plus the component catalog and a running showcase page — before UI mockups and before requirements. Use after visual-companion when: (1) greenfield project with no existing design system, (2) the user wants a distinctive visual identity before mockups, (3) no tailwind.config theme or CSS variables exist yet. Skip for brownfield projects with an established design system."
---

# Frontend Design — Design System Definition

Define the design system for a project before any UI is built: the visual design language (tokens) **and** the component catalog built from it, plus a showcase page that renders every component. This ensures every component, page, and interaction follows a coherent aesthetic — instead of agents making random visual choices during implementation.

The chain keeps this in three artifacts with one writer each, so a plan can say "use Button `primary/md`" instead of describing a button:

| Artifact | Answers | Owner |
|---|---|---|
| `docs/DESIGN-SYSTEM.md` | How does it look? Tokens, scales, patterns, do/don't | this skill (or `0b_intake` for brownfield extraction), curated by P7 |
| `docs/components.md` | What exists? Name, path, purpose, variants | **generated** from the doc block above each component export (`scripts/gen-component-registry.mjs`) — never hand-edited |
| `/dev/components` | Is it really true? Rendered, light and dark | built here, extended in P5, checked in P6 |

The PROJ-scoped `4_design/design-language.md` keeps the **why** (audience, tone, references, rejected directions). Same shape the chain uses for architecture: PROJ artifact carries the reasoning, the `docs/` baseline carries the standing truth.

## When to Use

- **Greenfield project** with no existing design system
- **Hybrid project** where Visual Companion found meaningful design-language gaps
- No custom theme in `tailwind.config` (only defaults)
- No CSS variables in `globals.css` beyond basics
- The user explicitly wants a distinctive visual identity

## When to Skip

- Brownfield project with established design tokens
- Design system reference already exists
- The user says "just use shadcn defaults"

For `hybrid` projects, do not reinvent the whole visual language. Fill only the documented gaps from Visual Companion and preserve existing tokens/components.

## Decomposed PROJ Handling

Design language may be cross-PROJ when brainstorming decomposes one seed into tightly linked UI PROJs. In that case, run this skill once for the approved PROJ family rather than inventing separate visual systems for each sibling.

Use this rule:

- **Shared design language:** audience, brand, navigation shell, visual tone, tokens, typography, status colors, component styling, and accessibility standards that should remain consistent across sibling PROJs.
- **Per-PROJ deltas:** only document differences required by a specific workflow, risk level, or user role.

Artifact handling:

- Write the canonical design language to the first/current UI PROJ's `specs/PROJ-<X>-<theme>/4_design/design-language.md`.
- In the document, include a `## Applies To` section listing sibling PROJs that should consume it.
- Later sibling PROJs should reference this canonical file from their Visual Companion, UI Mockup, PRD, architecture, and plan artifacts.
- If a sibling needs a local deviation, write a short local `4_design/design-delta.md` instead of creating a competing full design language.

## Input

- Concept doc from Step 1 (`specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`) — understand the app's purpose and audience
- Visual Companion output (`specs/PROJ-<X>-<theme>/2_visual-companion/layout-decision.md` and `layout-exploration.html`) — understand selected UI structure, `Project Mode`, `Shape Brief`, and interaction containers
- User preferences expressed during brainstorming

## Process

### 1. Understand Context

Ask the user (if not already clear from the spec):
- **Who uses this?** (developers, consumers, enterprise, creative professionals)
- **What's the tone?** (professional, playful, minimal, bold, luxurious, utilitarian)
- **Any references?** (existing apps, websites, or styles they admire)
- **Dark mode?** (yes/no/both)
- **Which UI stack?** — read `docs/ARCHITECTURE.md` § Stack; the framework, styling, and component library are decided there by `bootstrap` (0c) or extracted by `intake` (0b). Only if that section does not exist (a repo that predates it, or a discovery workspace with no code): detect from `package.json`, otherwise ask — and record the answer in `docs/ARCHITECTURE.md` § Stack, not only in the design language document. The components in step 3 are written in this stack.

Reference the stack from the design language document; do not copy the table. `3_architecture` inherits the same section and documents consequences — nobody re-opens the choice.

### 2. Define Design Language

Based on context, create a coherent design system with:

**Color Palette**
- Primary, secondary, accent colors with semantic names
- Background and surface colors
- Text colors (primary, secondary, muted)
- Status colors (success, warning, error, info)
- Dark mode variants if applicable

**Typography**
- Display font (headings, hero text) — distinctive, memorable
- Body font (paragraphs, UI text) — readable, complementary
- Mono font (code, data) — if applicable
- Scale: text-xs through text-4xl with specific use cases

**Spacing & Layout**
- Base spacing unit
- Content max-width
- Section padding patterns
- Card/component padding patterns

**Border Radius**
- Consistent radius tokens (none, sm, md, lg, full)

**Shadows & Effects**
- Shadow scale for depth
- Blur/backdrop effects if applicable

**Tone & Character**
- One sentence describing the visual personality
- What makes this design memorable (the "one thing")
- What to avoid (anti-patterns for this specific design)

### 3. Define The Component Catalog

Derive the component set from what the planned screens actually need — do not ship a fixed standard kit. Read the concept and `2_visual-companion/layout-decision.md`, list the UI pieces those screens require, and build only those. The catalog grows later, when a mockup or a user story demands a piece that does not exist yet (see *Extending The Design System*).

Rules:

- **Variant before component.** A new size, tone, or state of an existing component is a variant, not a new component. Only add a component when no existing one covers the anatomy.
- **Reuse the library.** If the chosen stack ships a component library (shadcn/ui, Radix, MUI), configure and theme its component instead of writing one. Write custom code only for pieces the library does not have.
- **No speculative components.** If no planned screen uses it, it does not belong in the catalog.

For each component define: name, purpose, variants, sizes, states (default, hover, focus, disabled, loading, error, empty where applicable), and the tokens it consumes.

### 4. Generate Artifacts

Create these files:

**`specs/PROJ-<X>-<theme>/4_design/design-language.md`** — The design language document:

```markdown
# Design Language — [Project Name]

> [One sentence: the visual personality]

## Applies To
- PROJ-<X>-<theme>: canonical owner
- PROJ-<Y>-<sibling>: consumes this design language

## Tone
[Professional/Playful/Minimal/Bold/etc. — with reasoning]

## Color Palette

### Light Mode
| Token | Value | Usage |
|-------|-------|-------|
| --primary | #... | Main actions, links |
| --secondary | #... | Secondary actions |
| --accent | #... | Highlights, badges |
| --background | #... | Page background |
| --surface | #... | Cards, panels |
| --text-primary | #... | Headings, body |
| --text-muted | #... | Secondary text |

### Dark Mode
[Same table with dark variants]

## Typography
| Role | Font | Weight | Usage |
|------|------|--------|-------|
| Display | [font] | 700 | Page headings, hero |
| Body | [font] | 400/500 | Paragraphs, UI text |
| Mono | [font] | 400 | Code blocks, data |

## Spacing
- Base unit: [4px/8px]
- Section padding: [py-16/py-24]
- Card padding: [p-4/p-6]
- Content max-width: [max-w-6xl]

## Border Radius
- Buttons: [rounded-md]
- Cards: [rounded-lg]
- Badges: [rounded-full]

## Shadows
[Scale definition]

## The One Thing
[What makes this design memorable and distinctive]

## Anti-Patterns
- [What NOT to do in this design]
```

Include a short implementation-facing section:

```markdown
## Implementation Notes
- Project mode: greenfield | hybrid
- UI stack: <framework + component library>
- Existing tokens/components to preserve:
- New tokens/components allowed:
- Existing app design takes precedence over exact mockup CSS: yes/no
```

**`tailwind.config.ts` updates** — Extend the Tailwind config with the design tokens (colors, fonts, spacing). Don't overwrite existing config — extend it.

**`src/app/globals.css` updates** — Add CSS variables for the color palette so shadcn/ui components inherit them.

**The components themselves** — implement each catalog entry in the chosen stack, in the project's component directory (for example `src/components/ui/`). Tokens only: no hardcoded hex values, no arbitrary pixel sizes. Every component must be usable without further styling by the consumer.

**`docs/DESIGN-SYSTEM.md`** — the curated baseline slot the chain already reserves for the design system (`0b_intake` lists it and points at this skill when no design system exists). It is injected into every `frontend-implementer` context bundle, so it is **capped at 80 lines** (`curation-caps.sh`) and holds rules only — no component inventory, no rationale:

```markdown
# Design System — [Project Name]

Stack: [framework + component library] · Showcase: `/dev/components`
Inventory: `docs/components.md` · Rationale: `specs/PROJ-<X>-<theme>/4_design/design-language.md`

## Tokens
| Purpose | Class | Never |
|---------|-------|-------|
| Page background | `bg-background` | `bg-white`, hex values |
| Primary action | `bg-primary text-primary-foreground` | own colors |
| Muted text | `text-muted-foreground` | `text-gray-500` |

## Scales
- Type: `text-xs sm base lg xl 2xl 3xl` — nothing in between, no `text-[17px]`
- Spacing: 4-step scale · card `p-6` · section `py-12` · stack gap `gap-4`
- Radius: button `rounded-md` · card `rounded-lg` · badge `rounded-full`
- Shadow: `shadow-sm` (card) · `shadow-lg` (overlay) — no others

## Patterns
| Pattern | Rule |
|---------|------|
| Page shell | `AppShell > PageHeader > content` — never a custom layout |
| Form | Label above field, error below, submit bottom-right |
| Empty/Loading/Error | Every data view has all three — use the catalog's state components |

## Do / Don't
- Do: compose from registered components (`docs/components.md`)
- Don't: hex colors, arbitrary sizes, a styled `<div>` that duplicates a component
- Don't: introduce a component that is not registered — escalate instead

## Extending
Variant before new component. Procedure: `1c_frontend-design` → Extending The Design System.
```

Write tokens as **classes, not hex palettes** — the implementer needs what to type. The hex values live in the design language document and in the CSS variables.

**`docs/components.md`** — the component registry. **Do not write it by hand.** Each component carries its own metadata in a doc block above the export, and `scripts/gen-component-registry.mjs` collects them:

```tsx
/** Actions. Not for navigation — use Link.
 *  @variants primary|secondary|ghost|destructive  @sizes sm|md|lg
 *  @states hover|focus|disabled|loading */
export function Button(props) { … }
```

Write the doc block while you write the component, then run `node scripts/gen-component-registry.mjs`. The purpose line and the "not for" hint are the only parts no parser can derive — they belong next to the code, not in a second list. From here on the registry stays current the same way: implementers (P5) write doc blocks, the wave gate verifies with `--check`, P7 curates the prose, never the table.

**Showcase page** — the one artifact that carries the detail, because it costs no context budget and cannot lie: every component with all variants, sizes, and states, in light and dark mode.

Where it lives:

- **App scaffold exists** → the route `/dev/components` (the path `6_qa` visits). Out of production navigation, no auth, no data fetching — it must render without a backend, or it is worthless in the P6 audit.
- **No scaffold yet** (discovery track, pre-scaffold greenfield) → `specs/PROJ-<X>-<theme>/4_design/component-showcase.html`, plain HTML+CSS with the components rebuilt by hand. **Same structure, same anchors** — P5 ports it to the route with the first UI story, and porting is then mechanical: keep the sections, replace each rebuild with the real import. Only the import line differs: it names the planned path, `→ @/components/ui/button (after scaffold)`.

Structure — three sections, in this order:

1. **`#tokens` — Foundations.** `#colors` (swatch grid: token · class · hex, light and dark **side by side** — contrast breaks are only visible in comparison), `#typography` (every step rendered at size with its class next to it), `#spacing`, `#radius`, `#shadow`.
2. **Components.** One section per registry entry, in **registry order (alphabetical)**, so a missing component is a visual diff and not a search. Each section carries: the purpose line verbatim from the doc block · the import line · one row per variant · one row per size · one row per state (incl. disabled, loading, error) · a `Don't:` example only where a real trap exists.
3. **Patterns.** One section per entry under `## Patterns` in `docs/DESIGN-SYSTEM.md` — no more, no less, so the list stays self-limiting. Anchors `#pattern-<name>`. A one-line rule ("label above field, error below, submit bottom-right") does not produce identical screens; the rendered composition does. This is what stops `1d_ui-mockup` and P5 from inventing their own form layout per screen.

**Anchors are the contract:** `id` = kebab-case of the registry name (`BulkBar` → `#bulk-bar`; patterns `#pattern-form`). Mockups, PRDs, and wave plans link straight to `/dev/components#bulk-bar`, so the registry needs no link column. `gen-component-registry.mjs --check` fails when a registered component has no section on the page — the showcase is the only one of the three artifacts that could otherwise rot in silence.

A sticky header carries: project · stack · links to `docs/DESIGN-SYSTEM.md` and `docs/components.md` · the light/dark toggle.

Static examples only — no props playground.

### 5. Verify

- Ensure CSS variables map correctly to Tailwind config
- Check that shadcn/ui theming will pick up the custom colors
- Verify font imports are added (Google Fonts link or next/font)
- Open the showcase page and check every component in light and dark mode
- Every `## Patterns` entry in `docs/DESIGN-SYSTEM.md` has a `#pattern-<name>` section on the page
- Run `node scripts/gen-component-registry.mjs --check` — it fails if a component has no doc block, the registry is stale, or a component has no showcase section
- Run `curation-caps.sh` (or count lines): `docs/DESIGN-SYSTEM.md` must fit its 80-line cap. If it does not, move detail to the showcase page — never to a second markdown file

## Extending The Design System

The design system is not sealed after this skill. When a later step needs a UI piece that does not exist, it runs a short excursion back into this skill instead of styling a one-off:

1. Check `docs/components.md`: does an existing component cover it, possibly as a new variant?
2. If a variant suffices, add the variant — do not add a component.
3. If a genuinely new component is needed, ask the user to confirm, then define it (anatomy, variants, states, tokens) with the same rules as step 3.
4. Implement it with its doc block, regenerate `docs/components.md`, and add its showcase section under `id="<kebab-name>"` — the registry check fails without it. Touch `docs/DESIGN-SYSTEM.md` only if a *rule* changed — a new component is not a rule change; a new pattern is, and then it also needs its `#pattern-<name>` section.
5. Only then use it in the mockup, plan, or implementation.

Callers: `1d_ui-mockup` when a screen needs a `New candidate:` piece, and `5_executing` when a user story needs a component that does not exist. Both must extend the system rather than work around it.

## Output

The design language document at `specs/PROJ-<X>-<theme>/4_design/design-language.md` (the rationale), `docs/DESIGN-SYSTEM.md` (the rules), `docs/components.md` (the inventory), the implemented components, and the showcase page (the proof). These become the reference for:
- **Step 1d (UI Mockup):** Mockups use the defined colors, fonts, spacing, and reference catalog components by name
- **Step 3 (Architecture):** Tech design documents the inherited UI stack and references the design tokens
- **Step 5 (Executing):** frontend-implementer composes catalog components instead of writing new UI
- **Step 6 (QA):** ui-auditor checks compliance against the catalog, the registry, and the showcase route

## Handoff

After the design language is approved, invoke `ui-mockup`. Do not invoke `requirements-engineer` directly from this skill; requirements must consume the approved mockups.

## Rules

- **Ask before deciding** — don't assume the user wants bold if they haven't said so
- **Commit to a direction** — wishy-washy "a bit of everything" designs fail. Pick a lane.
- **Respect shadcn/ui** — the tokens should work WITH shadcn's theming, not fight it
- **No feature code** — this step builds tokens, catalog components, and the showcase. No screens, no business logic, no data fetching.
- **Registered components must be real** — the registry is generated from code, so a paper component is impossible by construction. Keep it that way: never hand-edit `docs/components.md`.
- **One writer per artifact** — never copy the component inventory into `docs/DESIGN-SYSTEM.md`. Two lists drift, and both are paid for in every agent's context budget.
- **English** — all documentation in English
