---
name: chain-guide
description: "Context-aware guide through the 0-to-8 skill chain. Use when: (1) the user asks where they are or what to do next, (2) the user is unsure which skill to use, (3) starting a new feature or project, (4) the user says /chain-guide or /help. Detects current progress by checking existing files and recommends the next step."
---

# 0-to-8 Chain Guide

## Session Boundary

Through Step 4, each producing skill runs in its own user-started session.
Recommend the next skill from the saved artifacts, then stop at the handoff. Do not invoke the next producing
skill, including a prerequisite or another PROJ, in this session. Internal
helpers and cross-review remain in this session. `/compact` is not a new session.
End with a copyable start prompt naming the next skill, workspace, PROJ (if any),
actual input artifact paths and any blockers. The next session reads those
artifacts rather than relying on chat history. Do not create a separate session-context file.
If blocked, name the owning skill and issue in the prompt; do not claim readiness.
If the track is complete, report completion without inventing a next step.


Detect where the user is in the 0-to-8 skill chain and tell them what to do next.

## The Chain

| Step | Skill | Output / what it does |
|---|---|---|
| 0a | product-vision (once per product) | New build: `docs/PRODUCT.md` + the numbered PROJ map `specs/product-roadmap.md` (PROJ numbers, `Depends on`, `Status`) |
| 0c | bootstrap (once per project) | New build: stack into `docs/ARCHITECTURE.md` § Stack, real scaffold, build/test green, root `AGENTS.md` + `CLAUDE.md` pointer. Skipped on the discovery track |
| 0b | intake (once per repo) | Existing codebase: the same curated `docs/` baseline, extracted from a code scan + developer interview, sealed as a baseline commit (no state.json) |
| 1a | clarification (opt) | PM and stakeholder clarify the problem live → `specs/_clarification/<slug>-stakeholder_brief.md` |
| 1 | concept | Clarify, open the solution space, allocate PROJ-X → `specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md` + `PROJ-<X>-direction-log.md` |
| 1b | visual-companion (UI required) | Interactive layout exploration + project mode → `1b_visual-companion/layout-*.*` |
| 1c | frontend-design (opt) | Visual design language, greenfield or hybrid gaps → `1c_design/design-language.md` |
| 1d | prototyping (UI required) | Sitemap + mockups + `implementation-handoff.md` + `iteration-log.md` in `1d_prototypes/` |
| 1e | concept-sync (opt) | Reconcile iterated mockups and the chosen candidate back into the concept (`Concept Sync Log`, `Handoff Readiness`) |
| 2 | requirements-engineer | PRDs `2_PRDs/PROJ-<X>-PRD-<Y>-<desc>.md`: stories, ACs, edge cases; Linear handoff mode for the discovery track |
| 2b | handoff-package (opt) | Standalone zippable package for external UI/UX experts and developers → `2b_handoff/YYYY-MM-DD-handoff*/` |
| 2c | review-reconcile (opt) | Resolve PRD review gaps point by point → `2_PRDs/<prd>-review-decisions.md` + `review-changelog.md` |
| 2e | handoff-refinement (opt, receiving side) | Locate or record the team coordination location (`delivery-workspace.json`), refine the received package against code; product questions back, pinned per-repo inputs for Step 3 → `specs/PROJ-<X>-<theme>/runs/<YYYY-MM-DD-NN>/` + `external-handoff.json` (in the handoff's source repo a `-refinement` sibling of the product project) |
| 3 | architecture | PROJ-level tech design → `3-4_plan/PROJ-<X>-architecture.md` |
| 4 | writing-plans | Wave plans → `3-4_plan/PROJ-<X>-wave-<N>-plan.md`; propagates the UI handoff into frontend tasks |
| 5b | executing-large-model | Default Step 5: CP1 + P0 subskills (`decisions.md`, `state.json` `CP1:approved` → `P0:done`, `proj/PROJ-<X>` worktree + `scripts/`), then waves → code, tests, `5_progress/PROJ-<X>-progress.md` |
| 5 | executing | Same contracts, full step-by-step procedure, for weaker writer models; hosts the subskills and scripts |
| 6 | qa | E2E, security, simplicity, opposite-provider persona review; QA Test Results per PRD (interactive) or `5_progress/qa-finder-<ts>.md` (framework run, read-only finder); ledger records in `findings.json` |
| 7 | documentation | Conditionally `README.md`, `docs/PROJECT.md`, `docs/TECHNICAL.md`; merges approved `AGENTS.md` candidates |
| 8 | delivery (P8) | Conflict probe, PR via `gh` with rendered body, CI fix loop (max 3), Checkpoint 2 comment reconcile |

**Reading the numbers.** A bare number is a main-line step; a letter suffix is a variant at the same stage. `0a`/`0b`/`0c` are entry paths (0a+0c new build, 0b existing codebase — run one baseline path, not both); `1b`–`1e` run in sequence in the UI branch; `2b`/`2c` are optional product-side forks after requirements (`2b` packages PRDs for external experts on either track; `2c` reconciles returned review gaps into PRDs, concept and mockups); `2e` is the engineering-side receiving step for an external handoff (it replaces the `1_concept` entry and feed Step 3 in the production repo); `5b` is the default Step 5 and `5` its full-procedure fallback. Checkpoint 1 and P0 are subskills of Step 5, not steps. A skill without a number is not a step: `cross-review` is a mechanism invoked by producing skills (after concept, requirements, architecture, plans, P6 QA, P7 docs) and never routed to directly; `bugfixing` (reported defect, regression, "why did tests miss this"), `refactor-dreamer`, `sonar-cli`, `vibecoder`, `supabase-local-dev`, `update-chain` run outside the chain and create no PROJ.

Each PROJ has its folder `specs/PROJ-<X>-<theme>/`; each subfolder carries the number of the skill that writes it (architecture and plans share `3-4_plan/`). Progress is one file, `5_progress/PROJ-<X>-progress.md`. Framework runs add machine state `state.json` (only via `scripts/chain state`) and stage-local findings ledgers (`<stage>/findings.json`, aggregated by `scripts/chain findings list`) (only via `scripts/chain findings`).

**Unattended runs:** once Step 5 has sealed `P0:done`, it asks once (`5_executing/references/unattended-handoff.md`): run P5 to a PR unattended (`runner/run-phase.sh auto <X> <theme>`, detached; morning report `bash ~/.claude/skills/5_executing/scripts/chain render report morning specs`), drive it to the PR in this session under `/goal`, or continue interactively.

## Two Tracks

Detect which delivery track applies before recommending a next step.

- **Full chain (in-repo build):** (clarification) → concept → (UI prep 1b–1e) → requirements → architecture → plans → executing → QA → docs → delivery. This repo holds the implementation.
- **Product discovery (Linear handoff):** (clarification) → concept → visual-companion → prototyping (iterate) → concept-sync → requirements-engineer → optional handoff-package, then stop. The user only does product management and hands a PRD to a developer via Linear and/or an external UI/UX expert. **No code is written here and there is no codebase.** Do not recommend Steps 3–7. When a reviewer returns PRD gaps, recommend `review-reconcile` (2c).

A requested external `handoff-package` is also available in the full chain; it does not switch tracks.

Discovery track when any holds: the concept's `Handoff Readiness` sets `Delivery track: discovery (Linear handoff)` (written by `concept` at approval; a legacy concept without it: ask once); a `1d_prototypes/iteration-log.md` exists with stakeholder iterations but the repo has no application code; the user says they do discovery/PM only.

Notes: the folder structure is identical to the full chain (`concept` bootstraps it); git is optional (skip commit recommendations without a repo); brownfield discovery captures the existing product into `0_context/existing-state.md` during concept; `2b_handoff/` runs are immutable generated snapshots — after source artifacts change, recommend a new `handoff-package` run, never edit a prior one.

## Detect Current State

**External receiver routing (before Rule 0):** An incoming product handoff or a `delivery-workspace.json` marker takes the optional receiving path. Route to **handoff-refinement** before generic missing-PRD detection; it also handles a missing or uncertain team workspace through its [workspace contract](../2e_handoff-refinement/references/workspace-contract.md), including per-code-repo baseline evidence. A coordination-only repo never routes to product-vision or application intake; read-only evidence/questions need not wait for all intake baselines. Malformed markers are errors, not linear fallback. Source discovery completion does not establish receiving implementation readiness. No marker and no external request preserves the ordinary routing below.


**Rule 0 (baseline):** `docs/PRODUCT.md` missing → the curated baseline is missing; this comes before any other chain step (framework runs need it for the P0 context bundles). Code exists → **intake** (0b). No code → **product-vision** (0a), then **bootstrap** (0c) (skipped on the discovery track). Discovery for a single feature in an existing product → **concept**, which captures the existing state into `0_context/`. Run one baseline path, not both.

**Legacy layout rule:** PROJ folders with pre-rename subfolder names are detected as their current equivalents and never reported as "step missing". Mention the old layout once and offer the rename as an option, never a precondition: `references/legacy-layout.md`.

**Roadmap rule:** if `specs/product-roadmap.md` exists, read it before
recommending anything. It carries the PROJ numbers, the `Depends on`
ordering, and each entry's `Status`. A PROJ whose dependency is not
`shipped` waits — recommend the dependency instead. `planned` entries with
no `specs/PROJ-<X>-<theme>/` folder yet are the natural candidates for
**concept** (1).

**Step detection:** run `bash ~/.claude/skills/5_executing/scripts/chain status` from the workspace root and use its output; do not re-derive the state from the files. It is the single home of the detection rules: which artifacts mark each step (0–8, 1a–1e, 2b, 2c, 2e) done, legacy folder names and flat old-style paths (`specs/PROJ-*-spec.md`, `-plan.md`, `specs/concepts/`), `state.json` phase and status after Checkpoint 1, wave gates in `progress.md`, QA results and the documentation commit order. It reads only; it never writes `state.json`, a ledger or an artifact. Its default view lists one line per PROJ when there are several, then the step checklist (✅ done, 👉 current, ⬜ pending, ➖ skipped, 🔹 optional, ⛔ blocked) of the most advanced unfinished PROJ; `chain status <X>` shows another PROJ. A discovery PROJ with PRDs reports complete at step 2: do not recommend architecture; optionally suggest `handoff-package` (2b). A `⛔` step points to `5_progress/stop-report.md`.

The External receiver routing and Rule 0 above take precedence: the script applies both (a `delivery-workspace.json` marker or an `external-handoff.json` keeps handoff-refinement current until the refinement project README marks its current run `ready for architecture`; before a framework run starts, a missing baseline is the current step on the full chain), but if its output ever disagrees with them, follow these rules and report the mismatch.

What the script cannot decide stays a judgment here:
- Whether a concept-only PROJ is a UI feature (then **visual-companion** 1b before requirements) or backend/API (then **requirements-engineer** 2).
- Project mode for 1c/1d: prefer `1b_visual-companion/layout-decision.md` → `Project Mode`. Fallback: scan for existing app shell/components/tokens. If no reusable app shell, component set, design tokens, or real screens exist → greenfield. If existing screens/components/tokens/navigation meaningfully constrain the feature → brownfield. If some structure exists but important design/component gaps remain → hybrid.
- Whether the 1d screens referenced by `implementation-handoff.md` are complete (the script checks `sitemap.html` + `implementation-handoff.md`; component mode needs no HTML screens).
- A legacy concept without a `Delivery track` line in `Handoff Readiness` reports the full chain: ask once whether it is discovery.
- Flat old-style paths: recognise them, but recommend the current structure for new work.

## Respond to the User

Start with the `chain status --short` line, then tell the user the detected state (artifact path) and the next step, in one or two sentences:

| Detected state | Next step |
|---|---|
| No PROJ folder | **concept** (`/1_concept`) — it allocates PROJ-X and the folder. If a stakeholder must still explain the problem, **clarification** (`/1a_clarification`) first; a `specs/_clarification/*-stakeholder_brief.md` no concept cites → `/1_concept <brief path>` when confirmed, else list its blocking open questions |
| Concept, UI feature, nothing further | **visual-companion** (1b) before design, mockups and PRDs |
| Concept, backend/API feature | **requirements-engineer** (2) |
| Visual Companion exists, no design language/mockups/PRDs | Follow a `## Design System State` decision in `layout-decision.md` ("skip knowingly" → **prototyping** with greyscale wireframes). Else greenfield: **frontend-design** (1c) → **prototyping** (1d) → **requirements-engineer** (2); hybrid with gaps: 1c lightly, then 1d, 2; brownfield: 1d, then 2 |
| Design language exists, no mockups | **prototyping** (1d) — consumes the Visual Companion decision and design language |
| Mockups iterated, concept not synced | **concept-sync** (1e) before requirements |
| Mockups, concept in sync (or no concept-affecting iterations), no PRDs | **requirements-engineer** (2); mockups and handoff are required input. Discovery track: Linear handoff mode, the chain ends there |
| Discovery track, PRDs exist | The PRDs go to a developer in Linear; optionally **handoff-package** (2b) for external UI/UX or devs. Steps 3–7 do not apply |
| Discovery track, package assembled | Zip the latest dated run under `2b_handoff/` and share it. Chain complete |
| PRDs, no architecture | **architecture** (3) |
| Architecture, no wave plans | **writing-plans** (4) |
| Wave plans, no state.json | **executing-large-model** (5b): Checkpoint 1 (subskill, decision log, `CP1:approved`), P0 setup, then the waves; standalone preflights without the framework. Weaker writer model: **executing** (5) |
| `CP1:approved`, no P0 | **executing-large-model** (5b) runs P0, then asks once: unattended (`runner/run-phase.sh auto <X> <theme>`) or interactive |
| `P0:done`, no implementation | **executing-large-model** (5b): asks once, unattended (`runner/run-phase.sh auto <X> <theme>`, dual-lane, ends with an open PR) or interactive |
| `*:blocked` | Run parked: read `5_progress/stop-report.md` (what happened, rescue branch, cleanup list); after the fix `bash scripts/chain state transition <X> <theme> <phase> running`, re-run the phase |
| Some waves passed | Next wave `<N>` with the variant the run started in (5b or 5; progress.md records it) |
| All waves passed, no QA | **qa** (6) |
| QA passed, no docs | **documentation** (7) — conditional README/PROJECT/TECHNICAL, approval of `AGENTS.md` candidates, `CLAUDE.md` pointer-only |
| Docs committed, no PR (framework run) | **delivery** (8): conflict probe, PR from state.json + findings.json, CI polling, Checkpoint 2 |
| `P8:done` | PR open, waiting on Checkpoint 2: review and merge; **delivery** (8) reconciles review comments (fix now / debt / reject) |
| Docs complete (interactive run) | Ready for release |
| QA found bugs | Fix Critical/High, then re-run **qa** |

## Multiple PROJs

List each PROJ with the line `chain status` prints for it (`PROJ-1 · 👉 Step 5/8 Executing · next: qa`) and recommend the most advanced one first (finish what's started).

## Reference Skills

Not process steps. Root-cause debugging and verify-before-claiming-done discipline are written into `5_executing/SKILL.md` (`references/debugging.md`). Stack skills, recommended when the project uses them: `tailwind-css` (1d, 3, 5) for class patterns, dark mode and design tokens; `nextjs-app-router-patterns` (3, 4, 5) for Server vs. Client Components, routing, data fetching. Step 5 subagents receive them automatically when their story touches UI (Tailwind) or the Next.js App Router.
