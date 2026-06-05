---
name: chain-guide
description: "Context-aware guide through the 0-to-7 skill chain. Use when: (1) the user asks where they are or what to do next, (2) the user is unsure which skill to use, (3) starting a new feature or project, (4) the user says /chain-guide or /help. Detects current progress by checking existing files and recommends the next step."
---

# 0-to-7 Chain Guide

Detect where the user is in the 0-to-7 skill chain and tell them what to do next.

## The Chain

```
Step  Skill                  Output
----  ---------------------  ---------------------------------------------------------
  1   brainstorming          specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md
 1b   visual-companion (opt) specs/PROJ-<X>-<theme>/2_visual-companion/layout-*.*
 1c   frontend-design (opt)  specs/PROJ-<X>-<theme>/4_design/design-language.md
 1d   ui-mockup (UI req.)    specs/PROJ-<X>-<theme>/5_mockups/sitemap.html + mockups + implementation-handoff.md
  2   requirements-engineer  specs/PROJ-<X>-<theme>/3_PRDs/PROJ-<X>-PRD-<Y>-<desc>.md
  3   architecture           specs/PROJ-<X>-<theme>/6_plan/PROJ-<X>-architecture.md
  4   writing-plans          specs/PROJ-<X>-<theme>/6_plan/PROJ-<X>-wave-<N>-plan.md (per wave)
  5   executing              implements code + tests + specs/PROJ-<X>-<theme>/7_progress/PROJ-<X>-progress.md
  6   qa                     appends QA Test Results to each PRD file
  7   documentation          creates/updates docs/PROJECT.md
```

Each PROJ has its own folder `specs/PROJ-<X>-<theme>/` with numbered subfolders per step. Architecture and plans are siblings in `6_plan/`. Progress is a single file in `7_progress/` tracking all waves.

## Detect Current State

Scan `specs/PROJ-*/` folders to find the latest PROJ. For each PROJ, check:

1. `1_brainstorm/PROJ-<X>-concept.md` — concept written? → step 1 done
2. `2_visual-companion/layout-decision.md` + `layout-exploration.html` — visual companion present? → step 1b done
3. Project-mode detection: prefer `2_visual-companion/layout-decision.md` → `Project Mode`. Fallback: scan for existing app shell/components/tokens. If no reusable app shell, component set, design tokens, or real screens exist → greenfield. If existing screens/components/tokens/navigation meaningfully constrain the feature → brownfield. If some structure exists but important design/component gaps remain → hybrid.
4. `4_design/design-language.md` exists → step 1c done
5. `5_mockups/*.html` + `5_mockups/implementation-handoff.md` — mockups and UI handoff present? → step 1d done
6. `3_PRDs/PROJ-<X>-PRD-*.md` — at least one PRD? → step 2 done
7. `6_plan/PROJ-<X>-architecture.md` exists → step 3 done
8. `6_plan/PROJ-<X>-wave-*-plan.md` files exist → step 4 done (count waves by file glob)
9. `7_progress/PROJ-<X>-progress.md` exists → step 5 running or done. Read the file:
   - Has every wave marked complete? → step 5 done
   - Has "QA Results" section at top level? → step 6 done
10. Check `docs/PROJECT.md` for the current PROJ **and** that the latest `docs(PROJ-<X>): Update project documentation` commit is newer than the latest `feat(PROJ-<X>-PRD-<Y>)`/`test(PROJ-<X>)` commit → step 7 done. Skill 7 may additionally update `README.md`, `docs/TECHNICAL.md`, approved `AGENTS.md` entries, and pointer-only `CLAUDE.md`, but only `docs/PROJECT.md` is guaranteed to exist.
11. For back-compat, also check flat old-style paths (`specs/PROJ-*-spec.md`, `specs/PROJ-*-plan.md`, `specs/concepts/`) — treat as legacy, still recognise but recommend the new structure for new work.

## Respond to the User

Based on detected state, tell the user:

**No PROJ folder found:**
> "No feature work detected. Start with the **brainstorming** skill (`/1_brainstorming`) to explore your idea — it will allocate PROJ-X and set up the folder."

**Concept written, no visual companion output, no PRDs (UI feature):**
> "Concept for `PROJ-<X>-<theme>` found. This feature has a UI component. Recommended next step: use **visual-companion** (1b) to explore interactive layout approaches before design, mockups, and PRDs."

**Concept written, no PRDs (backend/API feature):**
> "Concept for `PROJ-<X>-<theme>` found. Next step: use **requirements-engineer** to write PRDs with user stories and acceptance criteria."

**Visual Companion exists, no design-language, no mockups, no PRDs (greenfield):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/2_visual-companion/`. Greenfield project detected. Next step: use **frontend-design** (1c), then **ui-mockup** (1d), then **requirements-engineer** (2)."

**Visual Companion exists, no design-language, no mockups, no PRDs (hybrid with design gaps):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/2_visual-companion/`. Hybrid project detected with design/component gaps. Next step: use **frontend-design** (1c) lightly for the gaps, then **ui-mockup** (1d), then **requirements-engineer** (2)."

**Visual Companion exists, no mockups, no PRDs (brownfield):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/2_visual-companion/`. Existing UI/design detected. Next step: use **ui-mockup** (1d), then **requirements-engineer** (2)."

**Design language exists, no mockups, no PRDs:**
> "Design language is ready at `specs/PROJ-<X>-<theme>/4_design/design-language.md`. Next step: use **ui-mockup** (1d); it consumes the Visual Companion decision and design language."

**Mockups exist, no PRDs:**
> "Mockups and UI implementation handoff are ready at `specs/PROJ-<X>-<theme>/5_mockups/`. Next step: use **requirements-engineer** (2); the mockups and handoff are required input for user stories, acceptance criteria, component reuse, and UI implementation notes."

**PRDs exist, no architecture:**
> "PRDs in `specs/PROJ-<X>-<theme>/3_PRDs/`. Next step: use **architecture** (3) to write the PROJ-level tech design."

**Architecture file exists, no wave plans:**
> "Architecture at `specs/PROJ-<X>-<theme>/6_plan/PROJ-<X>-architecture.md`. Next step: use **writing-plans** (4) to create per-wave implementation plans."

**Wave plans exist, no implementation (no progress.md):**
> "Wave plans ready in `specs/PROJ-<X>-<theme>/6_plan/`. Next step: use **executing** (5) to implement wave by wave with TDD — or **autonomous-execution** to run 5 → 6 → 7 end-to-end without prompts (balanced policy by default)."

**Progress.md exists, waves partially complete:**
> "Implementation in progress for `PROJ-<X>-<theme>`. Wave <N> is the next one. Continue with **executing** (5)."

**All waves complete, no QA results:**
> "All waves implemented. Next step: use **qa** (6) for end-to-end testing against the PRDs' acceptance criteria."

**QA passed, no docs:**
> "QA passed for `PROJ-<X>-<theme>`. Next step: use **documentation** (7) — conditionally updates `README.md`, `docs/PROJECT.md`, `docs/TECHNICAL.md`, asks for approval on any `AGENTS.md` candidates collected during QA, and keeps `CLAUDE.md` pointer-only."

**Documentation complete:**
> "Feature `PROJ-<X>-<theme>` is fully implemented, tested, and documented. Ready for release."

**QA found bugs:**
> "QA found bugs in `PROJ-<X>-<theme>`. Fix the Critical/High bugs, then re-run **qa**."

## Multiple PROJs

If multiple PROJ folders exist in different states, list them with their current step:

```
PROJ-1-auth:        Step 5 (executing) — wave 2 of 3 in progress
PROJ-2-dashboard:   Step 3 (architecture) — ready for tech design
PROJ-3-settings:    Step 6 (qa) — bugs found, needs fixes
```

Recommend working on the most advanced PROJ first (finish what's started).

## Quick Reference

If the user asks "what does each step do?":

| Step | Skill | What it does |
|------|-------|-------------|
| 1 | brainstorming | Explore the idea, allocate PROJ-X and thema slug, write concept |
| 1b | visual-companion (optional) | Interactive layout exploration plus project mode: greenfield/brownfield/hybrid |
| 1c | frontend-design (optional) | Visual design language — greenfield, or hybrid gaps only |
| 1d | ui-mockup (UI required) | HTML sitemap + per-screen mockups + `implementation-handoff.md` |
| 2 | requirements-engineer | PRDs from concept + approved mockups + UI handoff: user stories, acceptance criteria, edge cases |
| 3 | architecture | PROJ-level tech design covering all PRDs — data model, cross-cutting decisions |
| 4 | writing-plans | Wave-based implementation plans; propagates UI handoff into frontend/full-stack tasks |
| 5 | executing | Implement wave by wave with TDD, using UI handoff constraints where relevant |
| 6 | qa | End-to-end test all PRDs, security audit, QA Results appended per PRD |
| 7 | documentation | Conditionally update README.md, docs/PROJECT.md, docs/TECHNICAL.md; merge approved AGENTS.md candidates (≤40 lines) |

## Reference Skills

These skills are not process steps — they are **reference expertise** consulted during execution:

### Cross-Cutting (all projects)

| Skill | Consulted at | Purpose |
|-------|-------------|---------|
| `systematic-debugging` | 5, 6 | Root cause investigation, 4-phase debugging, 3-fix rule |
| `verification-before-completion` | 5, 6 | Gate function: run → read → verify → then claim |

### Tech Stack (project-specific)

| Skill | Consulted at | Purpose |
|-------|-------------|---------|
| `tailwind-css` | 2b, 3, 5 | Responsive utilities, dark mode, component patterns |
| `nextjs-app-router-patterns` | 3, 4, 5 | Server vs. Client Components, routing, data fetching, caching |

When to recommend them:
- **Step 1d (ui-mockup):** If the project uses Tailwind, mention that `tailwind-css` provides class patterns for mockups.
- **Step 3 (architecture):** If the stack includes Next.js → reference `nextjs-app-router-patterns` for RSC/routing decisions. If styling is Tailwind → `tailwind-css` for design token and dark mode decisions.
- **Step 5 (executing):** Subagents automatically receive these skills when their US touches UI (Tailwind) or Next.js App Router.
