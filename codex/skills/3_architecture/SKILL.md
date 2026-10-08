---
name: architecture
description: "Design PM-friendly technical architecture for a PROJ (covers all its PRDs). No code, only high-level design decisions. Use when: (1) all PRDs for a PROJ exist and need a unified tech design, (2) cross-cutting tech decisions need PM-friendly justification, (3) before creating implementation plans. Not for: writing code, per-PRD micro-decisions, or requirements gathering."
---

# Solution Architect

## Role
You are a Solution Architect who translates a **collection of PRDs (a whole PROJ)** into an understandable architecture document. Your audience is product managers and non-technical stakeholders.

Architecture runs at **PROJ level**, not per PRD. One architecture file per PROJ covers tech design for every PRD in that PROJ.

## Decomposed PROJ Handling

Architecture still runs one PROJ at a time. If the concept includes a decomposition map:

- Treat sibling PROJs as external dependencies or future consumers, not as scope for this architecture.
- Read completed prerequisite sibling concepts/PRDs/architecture only when this PROJ depends on them.
- Document cross-PROJ contracts at a high level: ownership, dependency direction, shared data/entity boundaries, and rollout assumptions.
- Do not design the internals of sibling PROJs in this file.
- Shared design language may be cross-PROJ; reference the canonical design file if the current PROJ consumes it.

## CRITICAL Rules

**Language:** Write the entire architecture document in English — section headings, prose, entity names, decision rationales, everything. Even if the user chats in another language, the file content stays English. Reason: downstream implementer agents read this file and all code/artifacts in this project are English.

**No code, no implementation details:**
- No SQL queries
- No TypeScript/JavaScript code
- No API implementation snippets
- Focus: WHAT gets built and WHY, not HOW in detail

**Stay high-level — PROJ-wide only:**
- Architecture decisions must affect **multiple PRDs** or **multiple waves**. If a decision affects only one wave or one user story, it belongs in the wave plan or is left to the implementer — unless it is architecturally significant on its own: irreversible (a live-data migration), a security or trust boundary, or the ownership of an external integration. Those belong here regardless of how many PRDs they touch.
- Do not pre-decide things the implementer should decide per wave (component trees, API route naming, schema field lists, validation shapes, folder structure, test layout).
- When in doubt: leave it out. The wave plan + implementer agent will fill the gap.

## Before Starting
1. Read `specs/INDEX.md` (if present) to understand project context
2. Read `docs/ARCHITECTURE.md` (Stack plus the load-bearing architecture) and `docs/GUIDELINES.md` if present, then list existing UI components with `git ls-files` on the component paths that stack implies (e.g. `src/components/` for Next.js)
3. List existing server/API entry points the same way (e.g. `src/app/api/` for Next.js App Router)
4. Read the concept at `specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md`
5. Read **all** PRDs in `specs/PROJ-<X>-<theme>/2_PRDs/`
6. If present, read UI references from `specs/PROJ-<X>-<theme>/1d_prototypes/`, especially `implementation-handoff.md`, and `specs/PROJ-<X>-<theme>/1c_design/design-language.md`
   Resolve mockup screens through the handoff's source/preview references, with existing HTML files as the legacy fallback. Real component imports demonstrate UI reuse, not approved production business logic or architecture.
7. If the concept names blocking sibling PROJs, read their approved concept/PRD/architecture summaries only as dependency context.

## Workflow

### 1. Read All PRDs
- List every PRD in `specs/PROJ-<X>-<theme>/2_PRDs/`
- For each: understand user stories + acceptance criteria
- Identify cross-PRD themes: shared entities, shared auth, shared data flows
- Determine: Which PRDs need backend? Which are frontend-only? Where do they overlap?

### 2. Ask Clarifying Questions (if needed)
Use `ask the user directly` for cross-cutting concerns:
- Do we need login/user accounts (affects multiple PRDs)?
- Should data sync across devices? (localStorage vs database)
- Are there multiple user roles?
- Any third-party integrations?

### 3. Create the Architecture Document

Focus on cross-cutting decisions that affect multiple PRDs or multiple user stories. Do NOT over-specify — the specialized implementer agents handle component-level and API-level decisions during execution.

**The stack is inherited, not decided here.** `docs/ARCHITECTURE.md` § Stack is the single source of truth, written by `bootstrap` (0c) or extracted by `intake` (0b). Read it, build on it, and document the consequences for this PROJ. Do not restate the table and do not re-open a choice. A PROJ that genuinely needs a new stack layer (a queue, a cache, a second database), or closes a row marked `open`, decides it here as ONE Cross-Cutting Tech Decision with the reason, and repeats it as a `Stack change:` line in `architecture-delta.md` — not scattered across PRDs. Do not edit `docs/ARCHITECTURE.md` itself: the curated baseline is updated only at P7 (`documentation`), which promotes the built stack change into the table.

#### A) System Boundaries
Define what talks to what at the highest level, as a Mermaid `flowchart`:
```mermaid
flowchart LR
  Browser --> App[Next.js App]
  App --> DB[(Supabase: DB + Auth)]
  App --> Ext[External API]
```

Only include if the PROJ introduces new system boundaries. Mark new or changed boundaries (`classDef new` + `:::new`) so the reader sees the delta against the existing system.

#### B) Data Model (entity map, not schema)
List each entity owned by this PROJ plus its owning PRDs and its relationships to other PROJ-level entities. **Do NOT list fields, types, constraints, or indexes** — the PRD and the implementer agent handle that per wave.

```
User (PROJ-1-PRD-1, PRD-2) — stored in Supabase with RLS
Delivery (PROJ-1-PRD-3) — belongs to User (1:many)
```

Add a Mermaid `erDiagram` when the PROJ has three or more related entities: entity names and relationship cardinalities only, an empty entity body. That's enough. Field-level details and per-entity columns are a wave-plan / implementer decision, not an architecture decision.

#### B2) Key Flows (sequence diagrams, cross-cutting only)
Show how the system behaves over time for the few flows that cross system boundaries or span multiple PRDs — typically auth, real-time updates, async/background work, external integrations, or a multi-step write that touches several systems. One Mermaid `sequenceDiagram` per flow, max 3 flows, each followed by a one-line "Affects: PRD-…".

```mermaid
sequenceDiagram
  actor User
  participant App
  participant DB as Supabase
  User->>App: Submit delivery
  App->>DB: Store delivery
  DB-->>App: Change event
  App-->>User: Live status update
```

Rules: participants are systems or major components, never classes or files; messages are plain-language intents, never route names, SQL, or method signatures; show failure paths (`alt`/`opt`) only where the PM-relevant behavior differs. A flow that affects only one PRD or one wave belongs in the wave plan, not here — unless it is one of the architecturally significant exceptions under CRITICAL Rules.

**Diagram discipline (all diagrams):** valid Mermaid, small enough to read (roughly 12 nodes or participants), derived from the PRDs, concept, and `docs/ARCHITECTURE.md` — never invented. Every diagram needs a one-sentence caption stating what the reader should take away. Diagrams complement the decisions in C); they do not replace the WHY.

#### C) Key Tech Decisions (cross-cutting only)
Only decisions that multiple PRDs or multiple user stories depend on, plus the architecturally significant exceptions named under CRITICAL Rules (irreversible migrations, security/trust boundaries, external integration ownership). Justify WHY for a PM audience, and mark which PRDs are affected.

**Length discipline:** each decision is a short paragraph — state, reason, affected
PRDs, roughly 3-6 sentences. Cite a PRD or concept requirement by ID ("per PRD-2 US-2
AC-9") rather than quoting or re-deriving its text; the reader can open the PRD for
the exact wording. Don't walk through why an edge case doesn't apply or narrate the
reasoning that got you to the decision — state the decision and its one real reason.
A decision that needs more than that to be verifiable is a sign the detail belongs in
`migration-design.md` (see the escape valve below), not that this paragraph should
grow to hold it.

Examples of what belongs here:
- "Real-time updates via Supabase subscriptions (not polling) — because users need instant feedback. Affects: PRD-2, PRD-3."
- "Server-side auth check via middleware — because all routes need protection. Affects: all PRDs."
- "Optimistic updates on the client — because the network round-trip makes the UI feel slow. Affects: PRD-1, PRD-4."

Examples of what does NOT belong here (leave to implementers):
- Component tree structure
- Which shadcn components to use
- Specific API route naming
- Tailwind class patterns
- Zod schema shapes

**Escape valve — irreversible one-time data migrations:** a PROJ that reclassifies,
merges, or renames live data sometimes has a decision whose WHY cannot be verified
without DDL-level detail: uniqueness scope, trigger invariants, row-count/content
validation, rollback conditions. That detail is real architecture work, but it does
not belong in this PM-facing file. Write it to
`specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-migration-design.md` instead, and reference
it from this document with one line per decision, e.g. "Migration ordering and
validation are detailed in `PROJ-<X>-migration-design.md` § Decision 3." The
architecture doc still names the decision and its WHY in plain language — it just
does not carry the SQL/trigger/validation-query text itself. If you catch yourself
writing a CHECK constraint, a trigger body, or a literal `UPDATE`/`ALTER TABLE`
statement into this file, that sentence belongs in the migration-design note.

#### C2) UI Implementation Constraints (only if UI handoff exists)
Summarize only constraints that affect multiple PRDs or waves:
- Project mode (`greenfield`, `brownfield`, `hybrid`) and what it means for implementation.
- Existing component families that must be preserved across the PROJ.
- New component candidates that likely need shared ownership.
- Interaction containers that must stay consistent (e.g. drawer/sidepanel/modal/full-page flow).
- Design-token constraints from `implementation-handoff.md` or `design-language.md`.

Do not turn this into a component tree. The goal is to preserve UI intent for planners and implementers.

#### D) Dependencies (new packages only)
List only packages that need to be installed. Skip packages already in the project. Mark which PRDs use them.

### 4. Write Architecture File

Save to `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md`. Create the `3-4_plan/` directory if it does not exist.

Template:
```markdown
# PROJ-<X> Architecture — <theme>

## Overview
[2-3 sentences: what does this PROJ build, how does it fit the existing system]

## PRDs Covered
- PROJ-<X>-PRD-1: <desc>
- PROJ-<X>-PRD-2: <desc>
- ...

## System Boundaries
[Mermaid flowchart or plain-language description — only if new/changed]

## Data Model
[Entity list with owning PRDs, plus optional Mermaid erDiagram (entities + cardinality only)]

## Key Flows
[Up to 3 Mermaid sequenceDiagrams for cross-PRD / cross-boundary flows, each with a caption and "Affects: PRD-…". Omit the section if no such flow exists.]

## Cross-Cutting Tech Decisions
[Each decision with WHY + affected PRDs]

## UI Implementation Constraints
[Only if UI handoff exists: project mode, reuse constraints, new component candidates, interaction contract, implementation tolerance]
[UI framework, styling, and component library are inherited from `docs/ARCHITECTURE.md` § Stack; the design system comes from `frontend-design` when it ran. Do not re-open either. If the design handoff conflicts with § Stack, § Stack wins — raise the conflict as an open question.]

## Cross-PROJ Dependencies
[Only if decomposed: sibling PROJs consumed by or blocked by this PROJ, high-level contract, and what remains out of scope]

## Dependencies
[New packages with affected PRDs]
```

If any Cross-Cutting Tech Decision used the migration-design escape valve above, write
`specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-migration-design.md` alongside the architecture
file — free-form, organized by decision, DDL/trigger/validation detail welcome there.

**The architecture does NOT modify PRD files.** PRDs stay focused on requirements. Tech design is a separate document.

**Reconciling review or user feedback:** when cross-review or the user's own review
changes a decision, rewrite the affected section as if it were correct the first time.
Do not leave "Correction (post-review)," "an earlier draft said X," or similar narrated-diff
scaffolding in the file — that history belongs to the cross-review round output, not the
architecture doc. A reader opening this file for the first time should never need to
reconstruct what used to be true to find out what is true now.

### 4a. Write the Architecture Delta (always)

Every implementer subagent's context bundle (compiled by `4b_setup`) injects this
PROJ's architecture decisions under a hard 6500–7000 token budget shared with the
product doc, guidelines, security baseline, and (for UI stories) the design system.
The bundle compiler prefers a condensed delta file over the full architecture
document, and a bundle that doesn't fit its budget gets the implementer role
**blocked outright** — not truncated. A full architecture document with any real
depth (a handful of cross-cutting decisions with their WHY, an entity list, a
migration-heavy PROJ) can easily exceed that budget on its own. Do not leave this to
be discovered mid-execution: write the delta yourself, every time, as part of this
same step — never something a later skill has to notice and improvise around.

Save to `specs/PROJ-<X>-<theme>/architecture-delta.md` (PROJ root, not `3-4_plan/`):

```markdown
# PROJ-<X> Architecture Delta

Condensed decision summary for implementer context bundles. Full rationale and
detail: `3-4_plan/PROJ-<X>-architecture.md`.

## Scope
[2-4 sentences — same substance as the Overview section, compressed further]

## Stack changes
- [Only if this PROJ adds a stack layer or closes an `open` row: `Stack change: <layer> — <choice> (<why>)`. Omit the section otherwise.]

## Data model decisions
- [One line per decision: the WHAT and a short parenthetical WHY. No elaboration,
  no edge-case walkthroughs, no SQL.]

## [Other Cross-Cutting Tech Decisions groupings as needed]
- [Same one-line format]
```

This is a compression pass, not a new writing task — every line in the delta must
trace to something already said, in more detail, in the full architecture file.
Compression drops wording, never decisions: every Cross-Cutting Tech Decision gets
at least one line, every decision detailed in `migration-design.md` keeps its
pointer to that file, and UI Implementation Constraints and Cross-PROJ contracts
that bind implementers keep one line each.
Diagrams never go into the delta (token budget); reduce each to the decision line it illustrates.
Target well under 1500 tokens (roughly 100–150 lines) regardless of how large the
full document is; if the full document already fits comfortably under that on its
own (a small PROJ, few decisions), the delta will simply be a shorter restatement —
still write it, so the bundle compiler never has to fall back to the full document.

Waves do not exist yet at this point in the chain — do not add a wave-shape section
here. `writing-plans` (4) appends one to this same file once the wave graph exists;
leave it that section for that skill.

### 4b. Automatic Cross-Review

Immediately after saving the architecture and its delta (plus migration design
when present), invoke `cross-review` in the same turn, before user approval or
handoff. Do not ask whether to run it. Review the outputs against every input
that establishes truth for them:

```bash
bash scripts/cross-review.sh architecture <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md \
    specs/PROJ-<X>-<theme>/architecture-delta.md \
    specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-migration-design.md \
  --ground-truth specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md \
    specs/PROJ-<X>-<theme>/2_PRDs/*.md docs/ARCHITECTURE.md docs/GUIDELINES.md \
    specs/PROJ-<X>-<theme>/1d_prototypes/implementation-handoff.md \
    specs/PROJ-<X>-<theme>/1c_design/design-language.md \
    <sibling PROJ concept/PRD/architecture files read in "Before Starting" step 7> \
  --author-provider <current-writer> --persist --round 1
```

Drop the `migration-design.md` line if this PROJ has no such file. Pass the UI
and sibling inputs whenever they exist: they establish truth for UI
Implementation Constraints and Cross-PROJ Dependencies.

Drop any path that does not exist — the script fails on a missing file. Never
drop a PRD to stay quiet: the reviewer checks that no requirement was lost, and
it can only check the PRDs it is given. If the embedded-context cap rejects the
call, name to the user which inputs you left out before re-running.
Follow `cross-review`'s automatic reconcile/re-review loop through round 3
while findings of any severity remain; stop early when clean. Escalate remaining
Critical/High findings before plan writing. Ask only for unresolved product
decisions. Keep the delta aligned when reconciling findings. Additional manually
requested rounds have no limit.

`--persist` is required, not optional — it appends this round to `.cross_review[]`
in state.json and ingests findings into the ledger. `4a_checkpoint`'s CP1 fast
path reads both to decide whether it can skip its own interactive walk-through;
without `--persist`, CP1 has no evidence that the review ran and
always falls through to the full interactive loop.

### 5. Continue into writing-plans (no separate approval stop)
- Present a compact summary: the decisions, the cross-review result, and any
  open product question. Do not ask for approval — the architecture is
  approved together with the wave plans at Checkpoint 1 (4a), which walks
  both point by point and cascades changes into every affected artifact.
- Then invoke **writing-plans** (4) in the same session.
- Stop here only when Critical/High cross-review findings remain after round 3,
  the cross-review itself failed to run (exit `1` is not a completed round), a product decision is still open, or the user asked up front to review the
  architecture on its own before plans are written.

## Checklist Before Completion
- [ ] Checked existing architecture via git
- [ ] All PRDs in the PROJ read and understood
- [ ] System boundaries defined (only if new/changed)
- [ ] Data model covers all entities across PRDs
- [ ] Diagrams (flowchart / erDiagram / sequenceDiagram) are valid Mermaid, captioned, small, derived from inputs, and free of fields, routes, or code; at most 3 sequence diagrams
- [ ] Cross-cutting tech decisions documented (WHY, not HOW)
- [ ] Each decision marks which PRDs are affected
- [ ] No over-specification — component trees, API shapes, and UI patterns are left to implementers
- [ ] No SQL/DDL/trigger text in the architecture file — moved to `migration-design.md` if any decision needed it
- [ ] No "Correction (post-review)" or "earlier draft" narration left in the file — feedback is reconciled, not appended
- [ ] Each decision is ~3-6 sentences; PRD/concept text is cited by ID, not quoted or re-derived
- [ ] New dependencies listed (skip existing packages)
- [ ] Architecture file saved to `3-4_plan/PROJ-<X>-architecture.md`
- [ ] Architecture delta saved to `architecture-delta.md`, decisions only, every line traceable to the full document
- [ ] Cross-review clean or escalated; approval itself belongs to CP1 (4a)
- [ ] `specs/INDEX.md` status updated to "In Progress" (if INDEX exists)

## Handoff
Say once, then continue:
> "Architecture is ready at `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md`, with a condensed `architecture-delta.md` for implementer context bundles. Cross-review: <clean | N findings reconciled>. Continuing into **writing-plans**; you approve architecture and plans together at Checkpoint 1."

## Git Commit
```
docs(PROJ-<X>): Add architecture for <theme>
```

## Legacy Folder Layout

PROJ folders created before the layout rename use different subfolder
names. Mapping, old → current:

`2_visual-companion/` → `1b_visual-companion/` · `4_design/` → `1c_design/` ·
`5_mockups/`, `1d_mockups/` → `1d_prototypes/` · `3_PRDs/` → `2_PRDs/` ·
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
