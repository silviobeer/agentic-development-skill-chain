---
name: handoff-package
description: "Assemble a standalone, distributable handoff package from discovery artifacts for downstream UI/UX experts and developers. Use after requirements-engineer on the product discovery track when the concept, mockups, and PRDs must be packaged into one self-contained folder (and ZIP) that external readers can consume without access to the rest of the repo. Produces a README index, a single-source-of-truth scope/decisions doc, role-split UI and developer handoffs, copied mockups, and a paste-ready Linear import."
---

# Handoff Package — Standalone Discovery Deliverable

Assemble everything decided during discovery — concept, mockups, iterations, PRDs — into one **standalone, self-contained package** that external readers can consume without access to the rest of the repository. The package serves two downstream audiences: an external **UI/UX expert** (e.g. a Figma design assignment) and **developers** (e.g. work imported into Linear).

This is the terminal step of the product discovery track. It does not invent product decisions; it curates, deduplicates, and reframes existing artifacts so an outside reader can act on them.

## When To Use

- The discovery track reached approved PRDs (`requirements-engineer` is done).
- The work will be handed to people outside this repo: a UI/UX designer, an external dev team, or a Linear board.
- A single distributable folder/ZIP is needed, not scattered `specs/` files.

## When To Skip

- The team continues into the full in-repo build (Steps 3–7) — the in-repo artifacts already suffice.
- Only a quick PRD→Linear handoff is needed with no external UI expert — `requirements-engineer`'s `linear-import.md` already covers that minimal path.

## Design Principles

- **Standalone:** every link inside the package is relative and resolves within the package. No reader needs the surrounding repo. The package must survive being zipped and emailed.
- **Single source of truth:** cross-cutting facts (vocabulary, invariant rules, scope matrix, decisions) live in exactly one file. Every other file references that file instead of restating it. Duplication is the enemy — it drifts.
- **Explicit conflict order:** state which artifact wins when two disagree. Binding behavior lives in the PRDs; mockups are reference only.
- **Role-split:** the UI/UX expert and the developer read different files. Don't force one audience through the other's detail.
- **Red lines vs. latitude:** be explicit about what an external expert may change and what must not drift.
- **Curate, don't restate the whole history:** an outside reader needs enough to act, not the full internal trail.

## Input

Read these inputs (discovery-track locations):

1. Reconciled concept: `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md` (with `Concept Sync Log` / `Handoff Readiness`)
2. PRDs: `specs/PROJ-<X>-<theme>/3_PRDs/PROJ-<X>-PRD-*.md`
3. Linear import (if present): `specs/PROJ-<X>-<theme>/3_PRDs/linear-import.md`
4. Mockups + sitemap + UI handoff: `specs/PROJ-<X>-<theme>/5_mockups/*.html`, `sitemap.html`, `implementation-handoff.md`
5. Iteration log: `specs/PROJ-<X>-<theme>/5_mockups/iteration-log.md`
6. Optional design language: `specs/PROJ-<X>-<theme>/4_design/design-language.md`
7. Optional Visual Companion decision: `specs/PROJ-<X>-<theme>/2_visual-companion/layout-decision.md`
8. Optional brownfield as-is reference: `specs/PROJ-<X>-<theme>/0_context/existing-state.md` and `0_context/references/`

If the concept lacks a `Handoff Readiness` section, run `concept-sync` (1e) first so the package is built from a reconciled concept.

## Workflow

### 1. Confirm Audiences And Scope

Ask the user which audiences the package targets:

- **UI/UX expert** (e.g. Figma assignment) — include the UI handoff and the assignment brief.
- **Developers** (e.g. Linear) — include the developer handoff and the Linear import.
- **Both** (default for greenfield discovery where a designer refines visuals and developers build).

Confirm the delivery phasing if the concept defines phases, and whether the design assignment is the full target product or only the first phase.

### 2. Create The Package Folder

Create a standalone package under:

```text
specs/PROJ-<X>-<theme>/8_handoff/
  README.md                     # index, reading order, source-of-truth + conflict rules, deliverables
  01-product-brief.md           # product framing: summary, promise, scope boundaries, user groups
  02-scope-and-decisions.md     # SINGLE SOURCE OF TRUTH: vocabulary, invariant rules, scope matrix, decisions register, phases
  03-requirements/              # the PRDs, copied in, one file per PRD
  04-ui-handoff.md              # UI/UX expert: personas, screen families, workflow contracts, red lines vs latitude, mockup caveats
  05-developer-handoff.md       # developers: functional domain rules, server-enforced invariants, explicit out-of-scope
  06-mockups/                   # standalone copy of mockups, design-language, sitemap, implementation-handoff, iteration-log
  linear-import.md              # paste-ready Linear issues (only when developers are an audience)
```

Copy mockups, design language, sitemap, implementation handoff, and iteration log into `06-mockups/` so the package is self-contained. Rewrite any links to use package-relative paths. Omit `04-ui-handoff.md` if UI experts are not an audience; omit `05-developer-handoff.md` and `linear-import.md` if developers are not.

### 3. Write `README.md` (Index)

This is the entry point. It must let an outside reader orient in one read:

```markdown
# <Product> Handoff Package

## What This Is
[One paragraph: the product, who this package is for, and that it is standalone.]

## Reading Order
1. `01-product-brief.md` — product framing
2. `02-scope-and-decisions.md` — vocabulary, rules, scope, decisions (canonical)
3. `03-requirements/` — binding PRDs
4. `04-ui-handoff.md` — for the UI/UX expert
5. `05-developer-handoff.md` — for developers
6. `06-mockups/` — reference prototype only

## Source Of Truth And Conflict Rules
- Cross-cutting definitions (vocabulary, invariant rules, scope matrix, decisions) are canonical in `02-scope-and-decisions.md`.
- Binding product behavior is defined by the PRDs in `03-requirements/`.
- Mockups in `06-mockups/` are reference only. If a mockup conflicts with a PRD, the PRD wins.

## Deliverables Expected From The Reader
- UI/UX expert: [e.g. complete Figma design + reusable components for the target product].
- Developers: [e.g. implementation per PRD; architecture is the developer's to design].

## Distribution
This folder is self-contained. Zip it and share it; no other repo access is required.
```

### 4. Write `01-product-brief.md`

Product-level reading frame so PRDs are not read as prototype instructions: product summary, the primary product promise, in-scope vs. out-of-scope boundaries, product areas, and user groups (short — full personas go in the UI handoff).

If `0_context/existing-state.md` exists (brownfield discovery), summarize the as-is starting point here and copy `0_context/references/` (screenshots, style-guide exports, saved links) into `06-mockups/references/` so external readers see what already exists. Feed the captured vocabulary into `02-scope-and-decisions.md` and the existing invariants into `05-developer-handoff.md` rather than restating them.

### 5. Write `02-scope-and-decisions.md` (Single Source Of Truth)

The one canonical file for cross-cutting facts:

- **Vocabulary:** a table of domain terms with meanings. Preserve product-specific or non-English terms exactly; note spelling conventions. These are product terms, not incidental labels — they must not be renamed silently.
- **Invariant rules that must not drift:** product rules that hold across all phases and surfaces, enforced in domain/server logic, not just UI.
- **Scope matrix:** what is in scope vs. explicitly out of scope; if phased, which feature lands in which delivery phase.
- **Decisions register:** resolved decisions and open questions with stable IDs.

```markdown
## Decisions Register
| ID | Status | Decision / Question | Rationale or Owner |
|----|--------|---------------------|--------------------|
| R1 | Resolved | <decision made during discovery> | <why> |
| D1 | Open | <question the downstream team must resolve> | <who decides> |
```

Other package files reference these sections by name instead of restating them.

### 6. Write `04-ui-handoff.md` (UI/UX Expert)

For the external designer. Include: project context, personas, screen families and workflow contracts, mandatory states, **red lines** (product rules the design must preserve) vs. **design latitude** (UX, visuals, navigation, components the expert owns), the role of the existing mockups (explore-only, not the final direction unless stated), and the explicit assignment + expected deliverables.

Be clear that the mockups communicate structure and flows, not final visual design — especially for greyscale wireframes.

### 7. Write `05-developer-handoff.md` (Developers)

For engineering. Include: the functional contract they must preserve (domain rules, multi-tenant/permission invariants, lifecycle rules), implementation phasing if any, and an explicit **out-of-scope** list so scope can't expand silently. State plainly that architecture, schema, framework, and sequencing are the developer's decisions; this package owns product behavior, not technical design.

If developers are an audience, regenerate or copy `linear-import.md` into the package root so each PRD maps to a Linear issue. Do not maintain Linear content in two places — the package copy is canonical once the package exists.

### 8. Self-Contained Check

Verify the package stands alone:

- No link points outside `8_handoff/`.
- Every referenced mockup, image, and design file is copied into `06-mockups/`.
- Cross-cutting facts appear once (in `02`) and are referenced elsewhere, not duplicated.
- Conflict order and source of truth are stated in `README.md`.
- Audience-only files are present/omitted per the chosen audiences.

### 9. Review And Package

Present the package tree and the `README.md` to the user. On approval, offer to zip it:

```bash
cd specs/PROJ-<X>-<theme> && zip -r PROJ-<X>-<theme>-handoff.zip 8_handoff
```

Ask the user to spot-check that an outside reader could act on it without further context.

## Completion Checklist

- [ ] Audiences confirmed (UI expert / developers / both)
- [ ] `8_handoff/` created with package-relative links only
- [ ] `README.md` states reading order, source of truth, and conflict rules
- [ ] `01-product-brief.md` frames the product without prototype bias
- [ ] `02-scope-and-decisions.md` holds vocabulary, invariants, scope matrix, and decisions register — referenced, not duplicated, elsewhere
- [ ] PRDs copied into `03-requirements/`
- [ ] `04-ui-handoff.md` present when UI experts are an audience, with red lines vs. latitude
- [ ] `05-developer-handoff.md` present when developers are an audience, with explicit out-of-scope
- [ ] Mockups, design language, sitemap, and iteration log copied into `06-mockups/`
- [ ] `linear-import.md` present when developers are an audience
- [ ] Self-contained check passed (no external links)
- [ ] User reviewed; ZIP offered

## Git Commit Format

```text
docs(PROJ-<X>): Assemble standalone handoff package for <theme>
```

Git is optional on the discovery track. If the workspace is not a git repository, skip the commit; the `8_handoff/` folder (and its ZIP) is the durable, distributable artifact.
