# 0-to-8 Skill Chain Process Documentation

This document is the expanded process reference for `chain-guide`. The executable skill instructions live in `SKILL.md`; this file explains the full chain, artifact map, and handoff rules in English.

## Core Flow

```text
0   chain-guide              Detect current PROJ state and recommend the next skill
1   brainstorming            Create the approved feature concept
1b  visual-companion         Explore UI shape for UI features
1c  frontend-design          Define or extend the design language when needed
1d  ui-mockup                Create sitemap, mockups, and UI implementation handoff
2   requirements-engineer    Write PRDs, user stories, acceptance criteria, and edge cases
3   architecture             Produce PROJ-level technical architecture
4   writing-plans            Split implementation into waves
5   executing                Implement waves with TDD and quality gates
6   qa                       Run E2E QA, security, persona, and simplicity review
7   documentation            Curate feature and technical documentation
```

Backend/API-only features may go from Step 1 directly to Step 2. UI features must go through the UI branch before Step 2 so requirements can consume approved visual decisions.

## Artifact Map

Each PROJ uses:

```text
specs/PROJ-<X>-<theme>/
  0_context/            existing-state capture, brownfield only
  1_brainstorm/         Step 1  concept
  1b_visual-companion/  Step 1b layout exploration and decision
  1c_design/            Step 1c design language or design delta
  1d_mockups/           Step 1d sitemap, mockups, implementation handoff
  2_PRDs/               Step 2  PRDs
  2b_handoff/           Step 2b standalone handoff package runs
  3-4_plan/             Steps 3+4 architecture and wave plans
  5_progress/           Step 5  progress tracking
```

Each folder prefix is the number of the skill that writes it. `3-4_plan/`
is the one shared folder: architecture (3) and wave plans (4) belong
together. Product-level artifacts live outside the PROJ folder —
`docs/PRODUCT.md` and `specs/product-roadmap.md`.

## Step Responsibilities

| Step | Skill | Required? | Output |
|---|---|---|---|
| 0 | `chain-guide` | As needed | Next-step recommendation |
| 0a | `product-vision` | New product | `docs/PRODUCT.md`, `specs/product-roadmap.md` |
| 0b | `intake` | Existing codebase | the curated `docs/` baseline, extracted |
| 0c | `bootstrap` | New build | `docs/ARCHITECTURE.md` § Stack, scaffold, `AGENTS.md` + `CLAUDE.md` |
| 1 | `brainstorming` | Required | `1_brainstorm/PROJ-<X>-concept.md` |
| 1b | `visual-companion` | UI only | `1b_visual-companion/layout-exploration.html` and `layout-decision.md` |
| 1c | `frontend-design` | Greenfield or hybrid UI gaps | `1c_design/design-language.md` or `design-delta.md` |
| 1d | `ui-mockup` | UI only | `1d_mockups/sitemap.html`, screen mockups, `implementation-handoff.md` |
| 1e | `concept-sync` | After mockup iterations | reconciled `1_brainstorm/PROJ-<X>-concept.md` |
| 2 | `requirements-engineer` | Required, including opposite-provider PRD review | `2_PRDs/PROJ-<X>-PRD-<Y>-*.md` |
| 2b | `handoff-package` | External handoff | `2b_handoff/YYYY-MM-DD-handoff*/` |
| 2c | `review-reconcile` | PRD review returned gaps | `2_PRDs/*-review-decisions.md`, `review-changelog.md` |
| 3 | `architecture` | Required | `3-4_plan/PROJ-<X>-architecture.md` |
| 4 | `writing-plans` | Required | `3-4_plan/PROJ-<X>-wave-<N>-plan.md` |
| 4a | `checkpoint` | Required | `decisions.md`, `state.json` sealed `CP1:approved` |
| 4b | `setup` | Required | PROJ branch, preflight, framework scripts, context bundles |
| 5 | `executing` | Required | Code, tests, `5_progress/PROJ-<X>-progress.md` |
| 6 | `qa` | Required before release, including six-persona opposite-provider evidence review | QA results appended to PRDs/progress |
| 7 | `documentation` | Required before closeout | `docs/PROJECT.md` and related docs |
| 8 | `delivery` | Required to ship | PR with rendered body, CI green, CP2 reconcile |

`cross-review` carries no number: producing skills invoke it. It is required
for requirements, P6 QA, and P7 documentation, and optional after concept,
architecture, and plans; it is not a step anyone routes to.

## UI Branch Rules

`visual-companion` decides the UI shape and project mode:

- `greenfield`: run `frontend-design`, then `ui-mockup`
- `hybrid` with design/component gaps: run `frontend-design` lightly, then `ui-mockup`
- `brownfield`: skip `frontend-design` and run `ui-mockup`

`ui-mockup` produces the handoff required by requirements, architecture, planning, and execution. It must identify component reuse, new component candidates, design tokens, interaction contract, demo-only mockup parts, and implementation tolerance.

## Decomposed PROJs

Brainstorming may split one broad seed into several PROJs. Downstream skills then run one PROJ at a time.

- Each PROJ has its own concept, PRDs, architecture, plans, execution, QA, and docs.
- Sibling PROJs are context, dependencies, or future scope.
- Shared design language is allowed for tightly linked UI PROJ families when `frontend-design` records an `Applies To` section.
- Do not absorb sibling scope into the current PROJ's PRDs or mockups unless the user explicitly asks for a combined review.

## Handoff Rules

- Step 1 hands UI features to `visual-companion`; backend/API features go to `requirements-engineer`.
- Step 1d must be complete before Step 2 for UI features.
- Step 2 PRDs must pass their required opposite-provider review and be approved before Step 3 or an external handoff.
- Step 3 architecture must be approved before Step 4 plans.
- Step 4 plans drive Step 5 execution.
- Step 5 hands off to Step 6 after implementation and quality gates.
- Step 6 either sends blockers back to execution or hands off to Step 7.
- Step 7 closes the PROJ documentation loop.

## Reference Skills

Reference skills are not process steps. They are expertise modules used inside process steps:

- `tailwind-css`: UI mockups, architecture, planning, execution, and QA when Tailwind is present
- `nextjs-app-router-patterns`: architecture, planning, and execution for Next.js App Router projects
- `accessibility`: QA and UI-related implementation checks when accessibility risk is present

Optional workflows are also outside the numbered chain. Use `bugfixing` for
one reported defect: reproduce it (in a real browser for browser-facing UI),
trace both the code cause and why the tests missed it, prove a regression test
red before the repair, then run a narrow fixer and at most three Ralph repair
attempts. Standalone evidence lives in
`specs/_bugfixing/BUGFIX-YYYYMMDD-HHMM-<slug>/bugfix-report.md`.

## Tooling Expectations

Run repository validation before publishing chain changes:

```bash
./scripts/validate.sh
```

The validator checks expected skill folders, frontmatter, pointer-only `CLAUDE.md`, and stale conventions.
