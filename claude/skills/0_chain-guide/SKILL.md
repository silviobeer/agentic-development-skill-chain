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
 1d   ui-mockup (UI req.)    specs/PROJ-<X>-<theme>/5_mockups/sitemap.html + mockups + implementation-handoff.md + iteration-log.md
 1e   concept-sync (opt)     reconciled 1_brainstorm/PROJ-<X>-concept.md (Concept Sync Log + Handoff Readiness)
  2   requirements-engineer  specs/PROJ-<X>-<theme>/3_PRDs/PROJ-<X>-PRD-<Y>-<desc>.md (+ linear-import.md on discovery track)
 2b   handoff-package (opt)  specs/PROJ-<X>-<theme>/8_handoff/ standalone package (+ zip) — discovery track only
  3   architecture           specs/PROJ-<X>-<theme>/6_plan/PROJ-<X>-architecture.md
  4   writing-plans          specs/PROJ-<X>-<theme>/6_plan/PROJ-<X>-wave-<N>-plan.md (per wave)
  5   executing              implements code + tests + specs/PROJ-<X>-<theme>/7_progress/PROJ-<X>-progress.md
  6   qa                     appends QA Test Results to each PRD file
  7   documentation          creates/updates docs/PROJECT.md
```

Each PROJ has its own folder `specs/PROJ-<X>-<theme>/` with numbered subfolders per step. Architecture and plans are siblings in `6_plan/`. Progress is a single file in `7_progress/` tracking all waves.

## Two Tracks

The same chain serves two delivery tracks. Detect which one applies before recommending a next step.

- **Full chain (in-repo build):** brainstorm → (UI prep) → requirements → architecture → plans → executing → QA → docs. Used when this repo will hold the implementation. A codebase exists or will exist here.
- **Product discovery (Linear handoff):** brainstorm → visual-companion → ui-mockup (iterate) → concept-sync → requirements-engineer → optional handoff-package, then stop. Used when the user only does product management — brainstorming, wireframes/mockups, stakeholder iteration — and hands a PRD to a developer via Linear and/or an external UI/UX expert. **No code is written here and there is no codebase.**

Detect the discovery track when any of these hold:

- The concept's `Handoff Readiness` sets `Delivery track: discovery (Linear handoff)`.
- A `5_mockups/iteration-log.md` exists with stakeholder iterations but the repo has no application code (no `package.json`/`src/` app, only `specs/` and `docs/`).
- The user states they are doing discovery/PM only and will hand off to developers.

On the discovery track, do not recommend Steps 3–7. The chain ends at `requirements-engineer` with `3_PRDs/linear-import.md`, optionally followed by `handoff-package` (2b) when a standalone deliverable for external UI/UX experts or developers is needed.

Discovery-track notes:

- **Folder structure is identical** to the full chain (`specs/PROJ-<X>-<theme>/`); `brainstorming` bootstraps it on first run. No manual scaffolding.
- **Git is optional.** If the workspace is not a git repo, skip commit recommendations; the files are the durable artifacts. Optionally suggest `git init` for iteration history.
- **Brownfield discovery** captures the existing product/design system/vocabulary into `0_context/existing-state.md` during brainstorming, since there is no codebase to scan.

## Detect Current State

Scan `specs/PROJ-*/` folders to find the latest PROJ. For each PROJ, check:

1. `1_brainstorm/PROJ-<X>-concept.md` — concept written? → step 1 done
2. `2_visual-companion/layout-decision.md` + `layout-exploration.html` — visual companion present? → step 1b done
3. Project-mode detection: prefer `2_visual-companion/layout-decision.md` → `Project Mode`. Fallback: scan for existing app shell/components/tokens. If no reusable app shell, component set, design tokens, or real screens exist → greenfield. If existing screens/components/tokens/navigation meaningfully constrain the feature → brownfield. If some structure exists but important design/component gaps remain → hybrid.
4. `4_design/design-language.md` exists → step 1c done
5. `5_mockups/*.html` + `5_mockups/implementation-handoff.md` — mockups and UI handoff present? → step 1d done
   - `5_mockups/iteration-log.md` with any entry marked `Affects concept: yes` **and** the concept has no `Concept Sync Log` entry covering that iteration → concept drifted, recommend `concept-sync` (1e) before requirements.
   - Concept contains `Concept Sync Log` / `Handoff Readiness` → step 1e done.
6. `3_PRDs/PROJ-<X>-PRD-*.md` — at least one PRD? → step 2 done. If `3_PRDs/linear-import.md` exists or `Handoff Readiness` is `discovery (Linear handoff)`, this PROJ is on the discovery track and is **complete at step 2** — do not recommend architecture. Optionally suggest `handoff-package` (2b) for an external standalone deliverable.
   - `8_handoff/README.md` exists → step 2b done; the standalone package is assembled.
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

**Mockups exist, iterated, concept not yet synced:**
> "Mockups for `PROJ-<X>-<theme>` were iterated (`5_mockups/iteration-log.md`) and the concept hasn't been reconciled yet. Next step: use **concept-sync** (1e) to flow the agreed mockup changes back into the concept before requirements."

**Mockups exist, concept in sync (or no concept-affecting iterations), no PRDs:**
> "Mockups and UI implementation handoff are ready at `specs/PROJ-<X>-<theme>/5_mockups/`. Next step: use **requirements-engineer** (2); the mockups and handoff are required input for user stories, acceptance criteria, component reuse, and UI implementation notes. For a discovery/Linear handoff, requirements-engineer runs in Linear handoff mode and the chain ends there."

**Discovery track, PRDs + linear-import.md exist, no package:**
> "`PROJ-<X>-<theme>` is a product-discovery PROJ. PRDs and `3_PRDs/linear-import.md` are ready to hand to a developer in Linear. Attach exported mockups to each issue. For a single standalone deliverable to share with an external UI/UX expert or dev team, optionally run **handoff-package** (2b). Otherwise the chain is complete — Steps 3–7 don't apply."

**Discovery track, handoff package assembled:**
> "The standalone handoff package for `PROJ-<X>-<theme>` is ready at `specs/PROJ-<X>-<theme>/8_handoff/`. Zip it and share it with the UI/UX expert and/or developers. This chain is complete — Steps 3–7 don't apply."

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
| 1d | ui-mockup (UI required) | HTML sitemap + per-screen mockups + `implementation-handoff.md` + `iteration-log.md`; greyscale-wireframe or design-system fidelity |
| 1e | concept-sync (optional) | Reconcile iterated mockup changes back into the concept; set delivery track (full chain vs. Linear handoff) |
| 2 | requirements-engineer | PRDs from concept + approved mockups + UI handoff: user stories, acceptance criteria, edge cases; Linear handoff mode produces `linear-import.md` |
| 2b | handoff-package (optional) | Standalone, zippable package for external UI/UX experts and developers: README index, single-source-of-truth scope/decisions, role-split handoffs, copied mockups |
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
