---
name: chain-guide
description: "Context-aware guide through the 0-to-8 skill chain. Use when: (1) the user asks where they are or what to do next, (2) the user is unsure which skill to use, (3) starting a new feature or project, (4) the user says /chain-guide or /help. Detects current progress by checking existing files and recommends the next step."
---

# 0-to-8 Chain Guide

Detect where the user is in the 0-to-8 skill chain and tell them what to do next.

## The Chain

```
Step  Skill                  Output
----  ---------------------  ---------------------------------------------------------
 0a   product-vision         docs/PRODUCT.md + specs/product-roadmap.md      ┐ new
 0c   bootstrap              docs/ARCHITECTURE.md §Stack + scaffold + AGENTS.md ┘ build
 0b   intake                 the same curated docs/ baseline, extracted from code
 1a   clarification (opt) specs/_clarification/<slug>-stakeholder_brief.md
  1   concept          specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md
 1b   visual-companion (opt) specs/PROJ-<X>-<theme>/1b_visual-companion/layout-*.*
 1c   frontend-design (opt)  specs/PROJ-<X>-<theme>/1c_design/design-language.md
 1d   prototyping (UI req.)    specs/PROJ-<X>-<theme>/1d_prototypes/sitemap.html + mockups + implementation-handoff.md + iteration-log.md
 1e   concept-sync (opt)     reconciled 1_concept/PROJ-<X>-concept.md (Concept Sync Log + Handoff Readiness)
  2   requirements-engineer  specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-<Y>-<desc>.md
 2b   handoff-package (opt)  specs/PROJ-<X>-<theme>/2b_handoff/YYYY-MM-DD-handoff*/ standalone package (+ zip) — discovery endpoint or requested full-chain export
 2c   review-reconcile (opt) specs/PROJ-<X>-<theme>/2_PRDs/<prd>-review-decisions.md + review-changelog.md — resolve PRD review gaps
  3   architecture           specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md
  4   writing-plans          specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-<N>-plan.md (per wave)
 5b   executing-large-model  default Step 5 — CP1 + P0 subskills: decisions.md, state.json CP1:approved → P0:done, proj/PROJ-<X> worktree + scripts/
                             then implements code + tests + specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md
  5   executing              same contracts with the full step-by-step procedure, for weaker writer models; hosts the subskills + scripts
  6   qa                     appends QA Test Results to each PRD file (+ ledger records in findings.json)
  7   documentation          creates/updates docs/PROJECT.md
  8   delivery (P8)          PR via gh with rendered body, CI green, CP2 comment reconcile
```

**Reading the numbers.** A bare number is a main-line step. A letter suffix
is a variant at the same stage — `1b`–`1e` run in sequence inside the UI
branch, `2b`/`2c` are optional forks, `0a`/`0b`/`0c` are alternative entry
paths (0a+0c for a new build, 0b for an existing codebase), and `5b` is the
default Step 5 — `5` is its full-procedure fallback for weaker models and
hosts the shared scripts. Checkpoint 1 and P0 setup are not separate steps:
they are subskills in `5_executing/subskills/`, run in subagents by whichever
Step 5 skill leads, before the first wave. A skill with no number is not a step at
all: `cross-review` is a mechanism invoked by producing skills, never routed
to directly, and `bugfixing`/`refactor-dreamer`/`sonar-cli` run outside the
chain.

Each PROJ has its own folder `specs/PROJ-<X>-<theme>/`, and each subfolder
carries the number of the skill that writes it — `1c_design/` is written by
`1c_frontend-design`, `2b_handoff/` by `2b_handoff-package`. Architecture
and plans share `3-4_plan/` because steps 3 and 4 both write there.
Progress is a single file in `5_progress/` tracking all waves. Framework runs additionally keep machine state in `state.json` (written only via `scripts/state.sh`) and the findings ledger in `findings.json` (written only via `scripts/ledger.mjs`).

**Once per product, before the first PROJ:** on a NEW build with no code
yet, `product-vision` (0a) establishes what the product is —
`docs/PRODUCT.md` (purpose, users, non-goals, success) plus the numbered
PROJ map in `specs/product-roadmap.md`, which is where PROJ numbers and
their `Depends on` ordering are allocated. Route to it when a new product
starts and `docs/PRODUCT.md` does not exist. On an EXISTING codebase the
counterpart is `intake` (0b) — same baseline, extracted instead of decided;
run one of the two, not both.

**Once per project, before the first PROJ:** on a new build, `bootstrap`
(0c) turns the vision into a running empty project — the stack decided into
`docs/ARCHITECTURE.md` § Stack (the single source of truth every skill reads
instead of assuming a framework), the real scaffold executed, `build` and
`test` verified green, root `AGENTS.md` plus the `CLAUDE.md` pointer written.
Route to it after `product-vision` when the workspace has no application
code. Skip it on the discovery track — there is no codebase there.

**Once per repo, before the first PROJ:** `intake` (0b) bootstraps the
curated context baseline — docs/PRODUCT.md, ARCHITECTURE.md, GUIDELINES.md,
DESIGN-SYSTEM.md, components.md, security-baseline.md, test-conventions.md,
root AGENTS.md — from a code scan (provenance-marked drafts) plus a
developer interview, reconciled via the bootstrap variant of executing's checkpoint subskill
and sealed as a baseline commit (no state.json — concept (1) creates one per PROJ).
`cross-review` is the opposite-provider review mechanism; it is required after
concept, requirements-engineer, architecture, plans, P6 QA (evidence check),
and P7 (docs truth-check). Users are never
routed to it directly.

Route a reported defect, regression, broken user flow, or request to explain
why tests missed a bug to the optional `bugfixing` skill. It operates outside
the numbered feature flow and does not create a PROJ for an ordinary repair.

**Autonomous full-chain runs** go through the phase runner: after
Step 5 seals `CP1:approved` through the checkpoint subskill, `runner/run-phase.sh auto <X> <theme>`
drives P0 → P5 → P6 → P7 → P8 unattended with dual provider lanes and
ends with an open PR and a one-line summary (morning report on demand:
`node runner/render-report.mjs morning specs`). Setup (P0) and skills 5/6/7/8 are the
same procedures the runner's lanes load — interactive use stays supported.

## Two Tracks

The same chain serves two delivery tracks. Detect which one applies before recommending a next step.

- **Full chain (in-repo build):** (optional clarification) → concept → (UI prep) → requirements → architecture → plans → executing → QA → docs. Used when this repo will hold the implementation. A codebase exists or will exist here.
- **Product discovery (Linear handoff):** (optional clarification) → concept → visual-companion → prototyping (iterate) → concept-sync → requirements-engineer → optional handoff-package, then stop. Used when the user only does product management — concept, wireframes/mockups, stakeholder iteration — and hands a PRD to a developer via Linear and/or an external UI/UX expert. **No code is written here and there is no codebase.**

A requested external `handoff-package` is also available after approved PRDs in the full chain. Component mockups are exported as screenshots and flow descriptions; packaging does not switch tracks or replace subsequent implementation steps.

Detect the discovery track when any of these hold:

- The concept's `Handoff Readiness` sets `Delivery track: discovery (Linear handoff)`.
- A `1d_prototypes/iteration-log.md` exists with stakeholder iterations but the repo has no application code (no `package.json`/`src/` app, only `specs/` and `docs/`).
- The user states they are doing discovery/PM only and will hand off to developers.

On the discovery track, do not recommend Steps 3–7. The chain ends at `requirements-engineer`, optionally followed by `handoff-package` (2b) when a standalone deliverable for external UI/UX experts or developers is needed. When a developer or stakeholder reviews the PRDs and returns gaps, recommend `review-reconcile` (2c) to resolve them point by point and update the artifacts before the next review cycle.

Discovery-track notes:

- **Folder structure is identical** to the full chain (`specs/PROJ-<X>-<theme>/`); `concept` bootstraps it on first run. No manual scaffolding.
- **Git is optional.** If the workspace is not a git repo, skip commit recommendations; the files are the durable artifacts. Optionally suggest `git init` for iteration history.
- **Brownfield discovery** captures the existing product/design system/vocabulary into `0_context/existing-state.md` during concept, since there is no codebase to scan.
- **Handoff packages are generated snapshots.** Existing `2b_handoff/YYYY-MM-DD-handoff*/` runs are immutable; only `handoff-package` (2b) may create or update files under `2b_handoff/`. If `review-reconcile` or another skill changes source artifacts, recommend a new `handoff-package` run instead of editing a prior package.

## Detect Current State

**Rule 0 (baseline):** `docs/PRODUCT.md` missing → the curated context
baseline is missing, and the next step depends on whether code exists:

- **Code exists** → **intake** (0b): extract the baseline from the codebase.
- **No code** (empty workspace, or specs only) → **product-vision** (0a),
  then **bootstrap** (0c) to decide the stack and stand up the project —
  unless this is the discovery track, where 0c is skipped.
- **Discovery track for a single feature in an existing product** → skip
  0a and go to **concept**, which captures the existing state into `0_context/`.

Either way this comes before any further chain step — framework runs need
the baseline for the P0 context bundles. Run one baseline path, not both.

**Legacy layout rule:** PROJ folders created before the layout rename carry
the old subfolder names (`2_visual-companion/`, `4_design/`, `5_mockups/`, `1d_mockups/`,
`3_PRDs/`, `8_handoff/`, `6_plan/`, `7_progress/`). Detect them as their
current equivalents — check an old `5_mockups/` with the same completion
criteria as `1d_prototypes/` below. Never report such a PROJ as
"step missing". Mention the old layout once and offer the rename as an
option, never as a precondition:

> "This PROJ uses the pre-rename folder layout. I can rename the folders to
> the current names (`git mv` per folder + fix the paths inside the PROJ's
> documents), or we continue with the existing layout — both work."

**Roadmap rule:** if `specs/product-roadmap.md` exists, read it before
recommending anything. It carries the PROJ numbers, the `Depends on`
ordering, and each entry's `Status`. A PROJ whose dependency is not
`shipped` waits — recommend the dependency instead. `planned` entries with
no `specs/PROJ-<X>-<theme>/` folder yet are the natural candidates for
**concept** (1).

Scan `specs/PROJ-*/` folders to find the latest PROJ. For each PROJ, check:

1. `1_concept/PROJ-<X>-concept.md` — concept written? → step 1 done
2. `1b_visual-companion/layout-decision.md` + `layout-exploration.html` — visual companion present? → step 1b done
   - `layout-decision.md` lists `Carried Forward` → several candidates are still live; step 1d is not done whatever exists in `1d_prototypes/`; recommend `prototyping` (1d) until one remains.
3. Project-mode detection: prefer `1b_visual-companion/layout-decision.md` → `Project Mode`. Fallback: scan for existing app shell/components/tokens. If no reusable app shell, component set, design tokens, or real screens exist → greenfield. If existing screens/components/tokens/navigation meaningfully constrain the feature → brownfield. If some structure exists but important design/component gaps remain → hybrid.
4. `1c_design/design-language.md` exists → step 1c done
5. `1d_prototypes/sitemap.html` + `1d_prototypes/implementation-handoff.md` + the screen sources referenced by the handoff — mockups and UI handoff present? → step 1d done. For legacy handoffs without screen references, check the screen HTML files (the sitemap alone is not a screen). Do not require HTML screens for component mode or a currently running server to recognize completed artifacts.
   - `1d_prototypes/iteration-log.md` with any entry marked `Affects concept: yes` **and** the concept has no `Concept Sync Log` entry covering that iteration → concept drifted, recommend `concept-sync` (1e) before requirements.
   - The concept still lists `Candidate Directions` and `layout-decision.md` has a `Selected Direction` → recommend `concept-sync` (1e) before requirements.
   - Concept contains `Concept Sync Log` / `Handoff Readiness` → step 1e done.
6. `2_PRDs/PROJ-<X>-PRD-*.md` — at least one PRD? → step 2 done. If `Handoff Readiness` is `discovery (Linear handoff)`, this PROJ is on the discovery track and is **complete at step 2** — do not recommend architecture. Optionally suggest `handoff-package` (2b) for an external standalone deliverable.
   - `2b_handoff/*/README.md` exists → step 2b done; the latest dated handoff package is assembled.
7. `3-4_plan/PROJ-<X>-architecture.md` exists → step 3 done
8. `3-4_plan/PROJ-<X>-wave-*-plan.md` files exist → step 4 done (count waves by file glob)
8b. `state.json` exists → framework run; read `.phase` + `.status` via `bash ~/.codex/skills/5_executing/scripts/state.sh get <X> <theme> '.phase + ":" + .status'`: `CP1:pending`/`CP1:running` → step 5 at Checkpoint 1; `CP1:approved`/`P0:running` → step 5 at P0 setup; `P0:done` → P0 complete; `P5:*`–`P8:*` → that phase is running/done; `*:blocked` → run parked, point to `5_progress/stop-report.md`
9. `5_progress/PROJ-<X>-progress.md` exists → step 5 running or done. Read the file:
   - Has every wave marked complete? → step 5 done
   - Any `2_PRDs/PROJ-<X>-PRD-*.md` has a `## QA Test Results` section? → step 6 done
10. Check `docs/PROJECT.md` for the current PROJ **and** that the latest `docs(PROJ-<X>): Update project documentation` commit is newer than the latest `feat(PROJ-<X>-PRD-<Y>)`/`test(PROJ-<X>)` commit → step 7 done. Skill 7 may additionally update `README.md`, `docs/TECHNICAL.md`, approved `AGENTS.md` entries, and pointer-only `CLAUDE.md`, but only `docs/PROJECT.md` is guaranteed to exist.
11. For back-compat, also check flat old-style paths (`specs/PROJ-*-spec.md`, `specs/PROJ-*-plan.md`, `specs/concepts/`) — treat as legacy, still recognise but recommend the new structure for new work.

## Respond to the User

Based on detected state, tell the user:

**No PROJ folder found:**
> "No feature work detected. Start with the **concept** skill (`/1_concept`) to explore your idea — it will allocate PROJ-X and set up the folder."

If a stakeholder still has to explain the problem, suggest **clarification** (`/1a_clarification`) first, run together with them. If `specs/_clarification/*-stakeholder_brief.md` exists with no concept citing it, recommend `/1_concept <stakeholder brief path>` when it is confirmed, or list its blocking open questions when it is not.

**Concept written, no visual companion output, no PRDs (UI feature):**
> "Concept for `PROJ-<X>-<theme>` found. This feature has a UI component. Recommended next step: use **visual-companion** (1b) to explore interactive layout approaches before design, mockups, and PRDs."

**Concept written, no PRDs (backend/API feature):**
> "Concept for `PROJ-<X>-<theme>` found. Next step: use **requirements-engineer** to write PRDs with user stories and acceptance criteria."

If `layout-decision.md` records a `## Design System State` decision, follow it instead of the greenfield/hybrid default below: "skip knowingly" goes straight to **prototyping** with greyscale wireframes.

**Visual Companion exists, no design-language, no mockups, no PRDs (greenfield):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/1b_visual-companion/`. Greenfield project detected. Next step: use **frontend-design** (1c), then **prototyping** (1d), then **requirements-engineer** (2)."

**Visual Companion exists, no design-language, no mockups, no PRDs (hybrid with design gaps):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/1b_visual-companion/`. Hybrid project detected with design/component gaps. Next step: use **frontend-design** (1c) lightly for the gaps, then **prototyping** (1d), then **requirements-engineer** (2)."

**Visual Companion exists, no mockups, no PRDs (brownfield):**
> "Visual Companion output is ready at `specs/PROJ-<X>-<theme>/1b_visual-companion/`. Existing UI/design detected. Next step: use **prototyping** (1d), then **requirements-engineer** (2)."

**Design language exists, no mockups, no PRDs:**
> "Design language is ready at `specs/PROJ-<X>-<theme>/1c_design/design-language.md`. Next step: use **prototyping** (1d); it consumes the Visual Companion decision and design language."

**Mockups exist, iterated, concept not yet synced:**
> "Mockups for `PROJ-<X>-<theme>` were iterated (`1d_prototypes/iteration-log.md`) and the concept hasn't been reconciled yet. Next step: use **concept-sync** (1e) to flow the agreed mockup changes back into the concept before requirements."

**Mockups exist, concept in sync (or no concept-affecting iterations), no PRDs:**
> "Mockups and UI implementation handoff are ready at `specs/PROJ-<X>-<theme>/1d_prototypes/`. Next step: use **requirements-engineer** (2); the mockups and handoff are required input for user stories, acceptance criteria, component reuse, and UI implementation notes. For a discovery/Linear handoff, requirements-engineer runs in Linear handoff mode and the chain ends there."

**Discovery track, PRDs exist, no package:**
> "`PROJ-<X>-<theme>` is a product-discovery PROJ. The PRDs are ready to hand to a developer in Linear. For a single standalone deliverable to share with an external UI/UX expert or dev team, optionally run **handoff-package** (2b). Otherwise the chain is complete — Steps 3–7 don't apply."

**Discovery track, handoff package assembled:**
> "The standalone handoff package for `PROJ-<X>-<theme>` is ready in the latest dated run folder under `specs/PROJ-<X>-<theme>/2b_handoff/`. Zip that run folder and share it with the UI/UX expert and/or developers. This chain is complete — Steps 3–7 don't apply."

**PRDs exist, no architecture:**
> "PRDs in `specs/PROJ-<X>-<theme>/2_PRDs/`. Next step: use **architecture** (3) to write the PROJ-level tech design."

**Architecture file exists, no wave plans:**
> "Architecture at `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md`. Next step: use **writing-plans** (4) to create per-wave implementation plans."

**Wave plans exist, no state.json (CP1 not yet run):**
> "Wave plans ready in `specs/PROJ-<X>-<theme>/3-4_plan/`. Next step: use **executing-large-model** (5b) — it first runs Checkpoint 1 through the checkpoint subskill (architecture + plans point by point, decision log, `CP1:approved` sealed in state.json), then P0 setup, then the waves. Without the framework it runs the standalone preflights instead. On a weaker writer model use **executing** (5) instead — same flow, full procedure."

**state.json says CP1:approved, no P0:**
> "Checkpoint 1 is approved for `PROJ-<X>-<theme>`. Next step: use **executing-large-model** (5b) — the setup subskill runs P0 (PROJ branch, tool/auth preflight, framework scripts) and it continues into the waves. Unattended alternative: `runner/run-phase.sh auto <X> <theme>` runs P0 and P5–P8."

**state.json says P0:done, no implementation:**
> "P0 setup is complete. Next step: **executing-large-model** (5b) — interactively in this session, or unattended via `runner/run-phase.sh auto <X> <theme>` (dual-lane, ends with an open PR and a one-line summary)."

**state.json says blocked:**
> "The run for `PROJ-<X>-<theme>` is parked (stop condition). Read `5_progress/stop-report.md` — it lists what happened, the rescue branch, and the cleanup list. After fixing the cause: `bash scripts/state.sh transition <X> <theme> <phase> running`, then re-run the phase."

**Progress.md exists, waves partially complete:**
> "Implementation in progress for `PROJ-<X>-<theme>`. Wave <N> is the next one. Continue with **executing-large-model** (5b) (or **executing** (5) if the run started there — `progress.md` records the variant)."

**All waves complete, no QA results:**
> "All waves implemented. Next step: use **qa** (6) for end-to-end testing against the PRDs' acceptance criteria."

**QA passed, no docs:**
> "QA passed for `PROJ-<X>-<theme>`. Next step: use **documentation** (7) — conditionally updates `README.md`, `docs/PROJECT.md`, `docs/TECHNICAL.md`, asks for approval on any `AGENTS.md` candidates collected during QA, and keeps `CLAUDE.md` pointer-only."

**Documentation complete, no PR (framework run):**
> "Docs are committed for `PROJ-<X>-<theme>`. Next step: use **delivery** (8) — conflict probe against main, PR with a rendered body from state.json + findings.json, CI polling, then Checkpoint 2 (human PR review)."

**PR open (state.json P8:done):**
> "The PR for `PROJ-<X>-<theme>` is open and waiting on Checkpoint 2 — review and merge it. When review comments come back, **delivery** (8) reconciles them point by point (fix now / debt / reject with rationale)."

**Documentation complete (interactive run, no framework):**
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
| 0a | product-vision (once per product) | New build: `docs/PRODUCT.md` (what/who/non-goals) + numbered PROJ map in `specs/product-roadmap.md` |
| 0c | bootstrap (once per project) | New build: stack into `docs/ARCHITECTURE.md` § Stack, real scaffold, build/test green, root `AGENTS.md` + `CLAUDE.md` |
| 0b | intake (once per repo) | Bootstrap the curated docs baseline: scan + provenance-marked drafts, developer interview, checkpoint reconcile, seal commit |
| 1a | clarification (optional) | PM and stakeholder clarify the problem live into `specs/_clarification/<slug>-stakeholder_brief.md` |
| 1 | concept | Explore the idea, allocate PROJ-X and thema slug, write concept |
| 1b | visual-companion (optional) | Interactive layout exploration plus project mode: greenfield/brownfield/hybrid |
| 1c | frontend-design (optional) | Visual design language — greenfield, or hybrid gaps only |
| 1d | prototyping (UI required) | HTML sitemap + component or standalone HTML mockups + `implementation-handoff.md` (runtime, screen references, flows) + `iteration-log.md`; execution mode is independent of visual fidelity |
| 1e | concept-sync (optional) | Reconcile iterated mockup changes back into the concept; set delivery track (full chain vs. Linear handoff) |
| 2 | requirements-engineer | PRDs from concept + approved mockups + UI handoff: user stories, acceptance criteria, edge cases; Linear handoff mode produces developer-ready PRDs |
| 2b | handoff-package (optional) | Standalone, zippable package for external UI/UX experts and developers: README index, single-source-of-truth scope/decisions, role-split handoffs, copied mockups |
| 3 | architecture | PROJ-level tech design covering all PRDs — data model, cross-cutting decisions |
| 4 | writing-plans | Wave-based implementation plans; propagates UI handoff into frontend/full-stack tasks |
| 5b | executing-large-model | Default Step 5: CP1 + P0 via the subskills below, then the waves with the same gates as 5, procedure replaced by invariants |
| 5 | executing | Full-procedure Step 5 for weaker writer models; hosts the subskills — CP1 (checkpoint subskill: reconcile loop → decision log → seal state.json) and P0 (setup subskill: branch + BASE_SHA, preflight, framework scripts), both in subagents; then implement wave by wave with TDD, using UI handoff constraints where relevant |
| 6 | qa | End-to-end test all PRDs, security audit, QA Results appended per PRD; read-only finder in framework runs (P6 controller fixes) |
| 7 | documentation | Conditionally update README.md, docs/PROJECT.md, docs/TECHNICAL.md; merge approved AGENTS.md candidates (≤40 lines) |
| 8 | delivery | Conflict probe, PR with rendered body, CI fix loop (max 3), Checkpoint 2 comment reconcile |

## Reference Skills

These skills are not process steps — they are **reference expertise** consulted during execution:

### Cross-Cutting (all projects)

| Skill | Consulted at | Purpose |
|-------|-------------|---------|
| (inlined in skill 5) | 5, 6 | Root-cause debugging discipline and verify-before-claiming-done discipline are written directly into `5_executing/SKILL.md` (see `references/debugging.md`) rather than factored into separate reference skills |

### Tech Stack (project-specific)

| Skill | Consulted at | Purpose |
|-------|-------------|---------|
| `tailwind-css` | 1d, 3, 5 | Responsive utilities, dark mode, component patterns |
| `nextjs-app-router-patterns` | 3, 4, 5 | Server vs. Client Components, routing, data fetching, caching |

When to recommend them:
- **Step 1d (prototyping):** If the project uses Tailwind, mention that `tailwind-css` provides class patterns for mockups.
- **Step 3 (architecture):** If the stack includes Next.js → reference `nextjs-app-router-patterns` for RSC/routing decisions. If styling is Tailwind → `tailwind-css` for design token and dark mode decisions.
- **Step 5 (executing):** Subagents automatically receive these skills when their US touches UI (Tailwind) or Next.js App Router.
