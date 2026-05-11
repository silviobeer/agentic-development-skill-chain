---
name: frontend-design
description: "Define the visual design language for a new project before UI mockups and before requirements. Use after visual-companion when: (1) greenfield project with no existing design system, (2) the user wants a distinctive visual identity before mockups, (3) no tailwind.config theme or CSS variables exist yet. Skip for brownfield projects with an established design system."
---

# Frontend Design — Design Language Definition

Define the visual identity and design language for a project before any UI is built. This ensures every component, page, and interaction follows a coherent aesthetic — instead of agents making random visual choices during implementation.

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

- Write the canonical design language to the first/current UI PROJ's `specs/PROJ-<X>-<thema>/4_design/design-language.md`.
- In the document, include a `## Applies To` section listing sibling PROJs that should consume it.
- Later sibling PROJs should reference this canonical file from their Visual Companion, UI Mockup, PRD, architecture, and plan artifacts.
- If a sibling needs a local deviation, write a short local `4_design/design-delta.md` instead of creating a competing full design language.

## Input

- Concept doc from Step 1 (`specs/PROJ-<X>-<thema>/1_brainstorm/PROJ-<X>-concept.md`) — understand the app's purpose and audience
- Visual Companion output (`specs/PROJ-<X>-<thema>/2_visual-companion/layout-decision.md` and `layout-exploration.html`) — understand selected UI structure, `Project Mode`, `Shape Brief`, and interaction containers
- User preferences expressed during brainstorming

## Process

### 1. Understand Context

Ask the user (if not already clear from the spec):
- **Who uses this?** (developers, consumers, enterprise, creative professionals)
- **What's the tone?** (professional, playful, minimal, bold, luxurious, utilitarian)
- **Any references?** (existing apps, websites, or styles they admire)
- **Dark mode?** (yes/no/both)

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

### 3. Generate Artifacts

Create these files:

**`specs/PROJ-<X>-<thema>/4_design/design-language.md`** — The design language document:

```markdown
# Design Language — [Project Name]

> [One sentence: the visual personality]

## Applies To
- PROJ-<X>-<thema>: canonical owner
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
- Existing tokens/components to preserve:
- New tokens/components allowed:
- Existing app design takes precedence over exact mockup CSS: yes/no
```

**`tailwind.config.ts` updates** — Extend the Tailwind config with the design tokens (colors, fonts, spacing). Don't overwrite existing config — extend it.

**`src/app/globals.css` updates** — Add CSS variables for the color palette so shadcn/ui components inherit them.

### 4. Verify

- Ensure CSS variables map correctly to Tailwind config
- Check that shadcn/ui theming will pick up the custom colors
- Verify font imports are added (Google Fonts link or next/font)

## Output

The design language document at `specs/PROJ-<X>-<thema>/4_design/design-language.md` plus updated config files. This document becomes the reference for:
- **Step 2b (UI Mockup):** Mockups use the defined colors, fonts, spacing
- **Step 3 (Architecture):** Tech design references the design tokens
- **Step 5 (Executing):** frontend-implementer follows the design language
- **Step 6 (QA):** ui-auditor checks compliance against the design language

## Handoff

After the design language is approved, invoke `ui-mockup`. Do not invoke `requirements-engineer` directly from this skill; requirements must consume the approved mockups.

## Rules

- **Ask before deciding** — don't assume the user wants bold if they haven't said so
- **Commit to a direction** — wishy-washy "a bit of everything" designs fail. Pick a lane.
- **Respect shadcn/ui** — the tokens should work WITH shadcn's theming, not fight it
- **No code beyond config** — this step defines the language, not components. Components come later.
- **English** — all documentation in English
