---
name: handoff-package
description: "Assemble a standalone, distributable handoff package from discovery artifacts for downstream UI/UX experts and developers. Use after requirements-engineer on the product discovery track when the concept, mockups, and PRDs must be packaged into one self-contained dated run folder (and ZIP) that external readers can consume without access to the rest of the repo. Produces a delta since the previous handoff, README index, manifest, single-source-of-truth scope/decisions doc, role-split UI and developer handoffs, copied mockups, and a paste-ready Linear import."
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
- **Delta first, full state second:** repeat recipients need to know what changed since the last handoff before they read the full package. Put the curated delta first, then include the complete current source of truth and audit trail behind it.
- **Explicit conflict order:** state which artifact wins when two disagree. Binding behavior lives in the PRDs; mockups are reference only.
- **Open questions stay actionable:** unresolved product questions are not buried in prose. They live in the decisions register with an owner, impact, and next decision point so downstream teams know what is blocked, what can proceed, and who decides.
- **Role-split:** the UI/UX expert and the developer read different files. Don't force one audience through the other's detail.
- **Red lines vs. latitude:** be explicit about what an external expert may change and what must not drift.
- **Curate, don't restate the whole history:** an outside reader needs enough to act, not the full internal trail.

## Input

Read these inputs (discovery-track locations):

1. Reconciled concept: `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md` (with `Concept Sync Log` / `Handoff Readiness`)
2. PRDs: `specs/PROJ-<X>-<theme>/3_PRDs/PROJ-<X>-PRD-*.md`
3. Linear import (if present): `specs/PROJ-<X>-<theme>/3_PRDs/linear-import.md`
4. Review changelog (if present): `specs/PROJ-<X>-<theme>/3_PRDs/review-changelog.md`
5. Review decision records (if present): `specs/PROJ-<X>-<theme>/3_PRDs/*-review-decisions.md`
6. Mockups + sitemap + UI handoff: `specs/PROJ-<X>-<theme>/5_mockups/*.html`, `sitemap.html`, `implementation-handoff.md`
7. Iteration log: `specs/PROJ-<X>-<theme>/5_mockups/iteration-log.md`
8. Optional design language: `specs/PROJ-<X>-<theme>/4_design/design-language.md`
9. Optional Visual Companion decision: `specs/PROJ-<X>-<theme>/2_visual-companion/layout-decision.md`
10. Optional brownfield as-is reference: `specs/PROJ-<X>-<theme>/0_context/existing-state.md` and `0_context/references/`
11. Previous handoff runs, if any: `specs/PROJ-<X>-<theme>/8_handoff/YYYY-MM-DD-handoff*/`

If the concept lacks a `Handoff Readiness` section, run `concept-sync` (1e) first so the package is built from a reconciled concept.

## Workflow

### 1. Confirm Audiences And Scope

Ask the user which audiences the package targets:

- **UI/UX expert** (e.g. Figma assignment) — include the UI handoff and the assignment brief.
- **Developers** (e.g. Linear) — include the developer handoff and the Linear import.
- **Both** (default for greenfield discovery where a designer refines visuals and developers build).

Confirm the delivery phasing if the concept defines phases, and whether the design assignment is the full target product or only the first phase.

### 2. Detect Previous Handoff And Create The Run Folder

Create a new standalone package run under `8_handoff/` for every invocation. Do not overwrite, patch, or reuse a previous handoff run. Name the run folder with the local date. Before writing it, look for the latest existing run folder matching `YYYY-MM-DD-handoff*`; that is the baseline for the delta section. If no previous run exists, mark this as the first handoff. `handoff-package` is the only skill that may create or update files under `8_handoff/`; all other skills must update source artifacts and then trigger a new package run when needed.

```text
specs/PROJ-<X>-<theme>/8_handoff/
  YYYY-MM-DD-handoff/           # one package run; if it already exists, append -02, -03, etc.
    00-what-changed-since-last-handoff.md
    README.md                   # index, reading order, source-of-truth + conflict rules, deliverables
    handoff-manifest.md         # run metadata, previous-run pointer, included artifacts, known open items
    01-product-brief.md         # product framing: summary, promise, scope boundaries, user groups
    02-scope-and-decisions.md   # SINGLE SOURCE OF TRUTH: vocabulary, invariant rules, scope matrix, decisions register, phases
    03-requirements/            # the PRDs, copied in, one file per PRD
    04-ui-handoff.md            # UI/UX expert: personas, screen families, workflow contracts, red lines vs latitude, mockup caveats
    05-developer-handoff.md     # developers: functional domain rules, server-enforced invariants, explicit out-of-scope
    06-mockups/                 # standalone copy of mockups, design-language, sitemap, implementation-handoff, iteration-log
    07-review-changelog.md      # what changed across review rounds (only when review-reconcile has run)
    08-review-decisions/        # internal/audit appendix: copied *-review-decisions.md files, if present
    linear-import.md            # paste-ready Linear issues (only when developers are an audience)
```

Use the local current date for `YYYY-MM-DD`. If `YYYY-MM-DD-handoff/` already exists, create the next unused suffix (`YYYY-MM-DD-handoff-02/`, then `-03/`, etc.) so each handoff run remains independently reviewable and shareable.

Copy mockups, design language, sitemap, implementation handoff, and iteration log into the run folder's `06-mockups/` so the package is self-contained. Rewrite any links to use package-relative paths within that run folder. If `3_PRDs/review-changelog.md` exists (a `review-reconcile` round ran), copy it in as `07-review-changelog.md` so downstream readers see what changed since the version they reviewed. If any `3_PRDs/*-review-decisions.md` files exist, copy them into `08-review-decisions/` as an audit appendix; do not put them in the primary reading path. Omit `04-ui-handoff.md` if UI experts are not an audience; omit `05-developer-handoff.md` and `linear-import.md` if developers are not.

### 3. Write `00-what-changed-since-last-handoff.md`

This is the first file in the reading order. It is a curated delta for repeat recipients, not a raw git diff and not the whole history.

If a previous run exists, compare the current source artifacts against that run's `handoff-manifest.md` and packaged files. Prefer git history when the workspace is a git repository; otherwise compare file presence, modified times, and manifest contents. Summarize only material handoff changes:

```markdown
# What Changed Since Last Handoff

Previous handoff: `../YYYY-MM-DD-handoff/` (or "none — first handoff")
Current handoff: `YYYY-MM-DD-handoff/`
Generated: YYYY-MM-DD

## Executive Delta
[3-6 bullets: what a returning UI/UX expert or developer must know before acting.]

## Requirements Changes
- [new/changed/removed PRDs or user stories, with file references]

## Decision Changes
- Resolved since last handoff: [IDs and outcomes]
- Newly open or still open: [IDs, owner, impact, next decision point]

## Review Rounds Since Last Handoff
- [review-changelog round labels and why they matter]

## Mockup / Design Reference Changes
- [changed screens, sitemap, design language, or implementation handoff notes]

## Impact By Audience
- UI/UX expert: [what to revisit, proceed with, or wait on]
- Developers: [what to implement differently, block on, or import into Linear]
```

If there are no material changes since the previous run, say that clearly and still point to the current package as the complete source of truth. For a first handoff, write a short "Initial package" delta that tells readers this is the first shareable baseline.

### 4. Write `handoff-manifest.md`

Record enough metadata for the next run to build a reliable delta:

```markdown
# Handoff Manifest

Run folder: `YYYY-MM-DD-handoff/`
Generated: YYYY-MM-DD
Previous handoff: `../YYYY-MM-DD-handoff/` or `none`
Git commit: `<sha>` or `not available`
Audiences: UI/UX expert | developers | both

## Included Artifacts
| Package path | Source path | Notes |
|--------------|-------------|-------|
| `03-requirements/<file>` | `3_PRDs/<file>` | PRD |

## Source Snapshot
| Source path | Last modified / commit | Purpose |
|-------------|------------------------|---------|

## Open Items At Handoff
| ID | Owner | Impact | Next Decision Point |
|----|-------|--------|---------------------|
```

Use this file as an internal package index; keep `README.md` reader-facing.

### 5. Write `README.md` (Index)

This is the entry point. It must let an outside reader orient in one read:

```markdown
# <Product> Handoff Package

## What This Is
[One paragraph: the product, who this package is for, and that it is standalone.]

## Reading Order
1. `00-what-changed-since-last-handoff.md` — start here, especially if you saw a previous handoff
2. `01-product-brief.md` — product framing
3. `02-scope-and-decisions.md` — vocabulary, rules, scope, decisions (canonical)
4. `03-requirements/` — binding PRDs
5. `04-ui-handoff.md` — for the UI/UX expert
6. `05-developer-handoff.md` — for developers
7. `06-mockups/` — reference prototype only
8. `07-review-changelog.md` — full review changelog, if present
9. `08-review-decisions/` — audit appendix for detailed review rationale, if present

## Change Scope
- `00-what-changed-since-last-handoff.md` is the curated delta for returning readers.
- The rest of this package is the complete current handoff baseline.
- `handoff-manifest.md` records package metadata for future handoff runs.

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

### 6. Write `01-product-brief.md`

Product-level reading frame so PRDs are not read as prototype instructions: product summary, the primary product promise, in-scope vs. out-of-scope boundaries, product areas, and user groups (short — full personas go in the UI handoff).

If `0_context/existing-state.md` exists (brownfield discovery), summarize the as-is starting point here and copy `0_context/references/` (screenshots, style-guide exports, saved links) into `06-mockups/references/` so external readers see what already exists. Feed the captured vocabulary into `02-scope-and-decisions.md` and the existing invariants into `05-developer-handoff.md` rather than restating them.

### 7. Write `02-scope-and-decisions.md` (Single Source Of Truth)

The one canonical file for cross-cutting facts:

- **Vocabulary:** a table of domain terms with meanings. Preserve product-specific or non-English terms exactly; note spelling conventions. These are product terms, not incidental labels — they must not be renamed silently.
- **Invariant rules that must not drift:** product rules that hold across all phases and surfaces, enforced in domain/server logic, not just UI.
- **Scope matrix:** what is in scope vs. explicitly out of scope; if phased, which feature lands in which delivery phase.
- **Decisions register:** resolved decisions and open questions with stable IDs. Every open item must name an owner/decision-maker, describe the downstream impact, and define the next decision point (for example, "before Figma starts", "before sprint planning", "developer meeting", or a dated review).

```markdown
## Decisions Register
| ID | Status | Decision / Question | Rationale / Impact | Owner | Next Decision Point |
|----|--------|---------------------|--------------------|-------|---------------------|
| R1 | Resolved | <decision made during discovery> | <why this is binding> | <who decided> | n/a |
| D1 | Open | <question the downstream team must resolve> | <what is blocked or at risk until decided> | <who decides> | <when/where it must be decided> |
```

Other package files reference these sections by name instead of restating them. If an open item affects UI/UX work, reference its ID from `04-ui-handoff.md` and state whether the designer may proceed with an assumption or must wait. If an open item affects engineering, reference its ID from `05-developer-handoff.md` and state whether implementation is blocked, can proceed behind an assumption, or belongs on the developer meeting agenda.

When review decision records exist, read them as source material but do not make external readers reconstruct the current state from them. Distill their outcomes into `02-scope-and-decisions.md`: resolved items become resolved decisions; deferred or still-open items become open decisions with owner, impact, and next decision point. `07-review-changelog.md` remains the reader-facing "what changed" narrative. `08-review-decisions/` is only the detailed audit trail for readers who need the full rationale.

### 8. Write `04-ui-handoff.md` (UI/UX Expert)

For the external designer. Include: project context, personas, screen families and workflow contracts, mandatory states, **red lines** (product rules the design must preserve) vs. **design latitude** (UX, visuals, navigation, components the expert owns), the role of the existing mockups (explore-only, not the final direction unless stated), and the explicit assignment + expected deliverables.

Be clear that the mockups communicate structure and flows, not final visual design — especially for greyscale wireframes.

### 9. Write `05-developer-handoff.md` (Developers)

For engineering. Include: the functional contract they must preserve (domain rules, multi-tenant/permission invariants, lifecycle rules), implementation phasing if any, and an explicit **out-of-scope** list so scope can't expand silently. State plainly that architecture, schema, framework, and sequencing are the developer's decisions; this package owns product behavior, not technical design.

If developers are an audience, regenerate or copy `linear-import.md` into the package root so each PRD maps to a Linear issue. Do not maintain Linear content in two places — the package copy is canonical once the package exists.

### 10. Self-Contained Check

Verify the package stands alone:

- No link points outside the dated run folder.
- `00-what-changed-since-last-handoff.md` exists and clearly states previous handoff baseline or first-handoff status.
- `handoff-manifest.md` exists and records run metadata, previous handoff, included artifacts, and open items.
- Every referenced mockup, image, and design file is copied into `06-mockups/`.
- `07-review-changelog.md` is included when `3_PRDs/review-changelog.md` exists.
- `08-review-decisions/` is included when any `3_PRDs/*-review-decisions.md` files exist, and the `README.md` labels it as audit appendix.
- Cross-cutting facts appear once (in `02`) and are referenced elsewhere, not duplicated.
- Every open decision has an owner, impact, and next decision point.
- Conflict order and source of truth are stated in `README.md`.
- Audience-only files are present/omitted per the chosen audiences.

### 11. Review And Package

Present the package tree and the `README.md` to the user. On approval, offer to zip it:

```bash
cd specs/PROJ-<X>-<theme>/8_handoff
RUN_FOLDER=YYYY-MM-DD-handoff
zip -r "$RUN_FOLDER.zip" "$RUN_FOLDER"
```

Ask the user to spot-check that an outside reader could act on it without further context.

## Completion Checklist

- [ ] Audiences confirmed (UI expert / developers / both)
- [ ] New dated run folder created under `8_handoff/` without overwriting prior runs
- [ ] Previous handoff detected, or first-handoff status recorded
- [ ] `00-what-changed-since-last-handoff.md` written as curated delta
- [ ] `handoff-manifest.md` written for this run
- [ ] `README.md` states reading order, source of truth, and conflict rules
- [ ] `01-product-brief.md` frames the product without prototype bias
- [ ] `02-scope-and-decisions.md` holds vocabulary, invariants, scope matrix, and decisions register — referenced, not duplicated, elsewhere
- [ ] Every open question has owner, downstream impact, and next decision point
- [ ] PRDs copied into `03-requirements/`
- [ ] `04-ui-handoff.md` present when UI experts are an audience, with red lines vs. latitude
- [ ] `05-developer-handoff.md` present when developers are an audience, with explicit out-of-scope
- [ ] Mockups, design language, sitemap, and iteration log copied into `06-mockups/`
- [ ] Review changelog copied to `07-review-changelog.md` when present
- [ ] Review decision records copied to `08-review-decisions/` when present and summarized into `02`
- [ ] `linear-import.md` present when developers are an audience
- [ ] Self-contained check passed (no external links)
- [ ] User reviewed; ZIP offered

## Git Commit Format

```text
docs(PROJ-<X>): Assemble standalone handoff package for <theme>
```

Git is optional on the discovery track. If the workspace is not a git repository, skip the commit; the dated run folder under `8_handoff/` (and its ZIP) is the durable, distributable artifact.
