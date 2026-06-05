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
- Architecture decisions must affect **multiple PRDs** or **multiple waves**. If a decision affects only one wave or one user story, it belongs in the wave plan or is left to the implementer.
- Do not pre-decide things the implementer should decide per wave (component trees, API route naming, schema field lists, validation shapes, folder structure, test layout).
- When in doubt: leave it out. The wave plan + implementer agent will fill the gap.

## Before Starting
1. Read `specs/INDEX.md` (if present) to understand project context
2. Check existing components: `git ls-files src/components/`
3. Check existing APIs: `git ls-files src/app/api/`
4. Read the concept at `specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md`
5. Read **all** PRDs in `specs/PROJ-<X>-<theme>/3_PRDs/`
6. If present, read UI references from `specs/PROJ-<X>-<theme>/5_mockups/`, especially `implementation-handoff.md`, and `specs/PROJ-<X>-<theme>/4_design/design-language.md`
7. If the concept names blocking sibling PROJs, read their approved concept/PRD/architecture summaries only as dependency context.

## Workflow

### 1. Read All PRDs
- List every PRD in `specs/PROJ-<X>-<theme>/3_PRDs/`
- For each: understand user stories + acceptance criteria
- Identify cross-PRD themes: shared entities, shared auth, shared data flows
- Determine: Which PRDs need backend? Which are frontend-only? Where do they overlap?

### 2. Ask Clarifying Questions (if needed)
Use `AskUserQuestion` for cross-cutting concerns:
- Do we need login/user accounts (affects multiple PRDs)?
- Should data sync across devices? (localStorage vs database)
- Are there multiple user roles?
- Any third-party integrations?

### 3. Create the Architecture Document

Focus on cross-cutting decisions that affect multiple PRDs or multiple user stories. Do NOT over-specify — the specialized implementer agents handle component-level and API-level decisions during execution.

#### A) System Boundaries
Define what talks to what at the highest level:
```
Browser → Next.js App → Supabase (DB + Auth)
                      → External API (if any)
```

Only include if the PROJ introduces new system boundaries.

#### B) Data Model (entity map, not schema)
List each entity owned by this PROJ plus its owning PRDs and its relationships to other PROJ-level entities. **Do NOT list fields, types, constraints, or indexes** — the PRD and the implementer agent handle that per wave.

```
User (PROJ-1-PRD-1, PRD-2) — stored in Supabase with RLS
Delivery (PROJ-1-PRD-3) — belongs to User (1:many)
```

That's enough. Field-level details and per-entity columns are a wave-plan / implementer decision, not an architecture decision.

#### C) Key Tech Decisions (cross-cutting only)
Only decisions that multiple PRDs or multiple user stories depend on. Justify WHY for a PM audience, and mark which PRDs are affected.

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

Save to `specs/PROJ-<X>-<theme>/6_plan/PROJ-<X>-architecture.md`. Create the `6_plan/` directory if it does not exist.

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
[diagram or plain-language description — only if new/changed]

## Data Model
[Entity list with owning PRDs]

## Cross-Cutting Tech Decisions
[Each decision with WHY + affected PRDs]

## UI Implementation Constraints
[Only if UI handoff exists: project mode, reuse constraints, new component candidates, interaction contract, implementation tolerance]

## Cross-PROJ Dependencies
[Only if decomposed: sibling PROJs consumed by or blocked by this PROJ, high-level contract, and what remains out of scope]

## Dependencies
[New packages with affected PRDs]
```

**The architecture does NOT modify PRD files.** PRDs stay focused on requirements. Tech design is a separate document.

### 5. User Review
- Present the architecture for review
- Ask the user to review the architecture artifact with a different model before approval, for example GPT reviewing Claude output or Claude reviewing GPT output
- Ask: "Does this design make sense across all PRDs? Any questions?"
- Wait for approval before suggesting handoff

## Checklist Before Completion
- [ ] Checked existing architecture via git
- [ ] All PRDs in the PROJ read and understood
- [ ] System boundaries defined (only if new/changed)
- [ ] Data model covers all entities across PRDs
- [ ] Cross-cutting tech decisions documented (WHY, not HOW)
- [ ] Each decision marks which PRDs are affected
- [ ] No over-specification — component trees, API shapes, and UI patterns are left to implementers
- [ ] New dependencies listed (skip existing packages)
- [ ] Architecture file saved to `6_plan/PROJ-<X>-architecture.md`
- [ ] User has reviewed and approved
- [ ] `specs/INDEX.md` status updated to "In Progress" (if INDEX exists)

## Handoff
After approval, tell the user:
> "Architecture is ready at `specs/PROJ-<X>-<theme>/6_plan/PROJ-<X>-architecture.md`. Next step: use the **writing-plans** skill to create wave-based implementation plans. Each wave becomes its own plan file."

## Git Commit
```
docs(PROJ-<X>): Add architecture for <theme>
```
