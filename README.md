# Agentic Development Skill Chain

An opinionated skill chain for agentic software development, maintained in
parallel for Codex and Claude, plus an agent workflow framework that runs
the execution half of the chain unattended — dual provider lanes, machine-
readable state, a findings ledger, and hard gates instead of good
intentions.

Not a developer, or just want the plain-language version of what this does
and why? Start with [docs/WHY.md](docs/WHY.md).

The chain turns a rough product idea into a buildable concept, explores UI
shape when needed, writes requirements, creates architecture and
implementation plans, executes the work wave by wave, runs QA, curates
documentation, and delivers a PR. Two human checkpoints frame the
autonomous middle: plan approval before execution starts (CP1) and PR
review after delivery (CP2).

Before the first PROJ it runs once at the product level: a new build goes
through `product-vision` (what the product is and is not, plus a numbered
PROJ map) and `bootstrap` (the stack decided into one table, the real
scaffold stood up, agent files written); an existing codebase goes through
`intake`, which reaches the same curated baseline by extraction.

## The Chain

| Step | Skill | What it does |
|------|-------|--------------|
| 0 | `chain-guide` | Detect project state, route to the right next step |
| 0a | `product-vision` | Once per product, new build: interview into `docs/PRODUCT.md` (what/who/non-goals) and cut the product into a numbered PROJ map in `specs/product-roadmap.md` |
| 0b | `intake` | Once per repo: bootstrap the curated docs baseline from a code scan (provenance-marked drafts) + developer interview, reconciled via checkpoint, sealed as a commit |
| 0c | `bootstrap` | Once per project, new build: decide the stack into `docs/ARCHITECTURE.md` § Stack, run the real scaffold, verify build/test green, write root `AGENTS.md` + `CLAUDE.md` pointer |
| 1 | `brainstorming` | Explore the idea, allocate PROJ-X, write the concept |
| 1b | `visual-companion` (opt) | Interactive layout exploration, project mode detection |
| 1c | `frontend-design` (opt) | Design system — tokens, component catalog, showcase page |
| 1d | `ui-mockup` (UI req.) | HTML sitemap + component-based or standalone HTML mockups + implementation handoff |
| 1e | `concept-sync` (opt) | Reconcile iterated mockups back into the concept |
| 2 | `requirements-engineer` | PRDs: user stories, acceptance criteria, edge cases, required opposite-provider review before handoff |
| 2b | `handoff-package` (opt) | Standalone zippable package for external experts |
| 2c | `review-reconcile` (opt) | Resolve PRD review gaps point by point |
| 3 | `architecture` | PROJ-level tech design across all PRDs; flows straight into 4 when its cross-review is clean |
| 4 | `writing-plans` | Wave-based implementation plans; flows straight into 4a — CP1 is the single planning approval |
| 4a | `checkpoint` | CP1/CP2/bootstrap as structured reconcile loops with a decision log; CP1 seals `state.json` to `CP1:approved` |
| 4b | `setup` | P0 once per PROJ: persistent isolated worktree, branch, preflight, framework scripts, dependencies, context bundles |
| 5 | `executing` | Worker-owned code/test/fix edits, TDD, one wave-scoped Ralph pass, hard wave gates, an integration-focused PROJ gate, then direct handoff to mandatory Skill 6 |
| 5b | `executing-large-model` (opt) | Lean Step 5 for frontier models: same gates, state, and QA handoff as `executing`, procedure replaced by intent and invariants; runner override `SKILLCHAIN_P5_SKILL` |
| 6 | `qa` | End-to-end QA plus required six-persona opposite-provider evidence review; read-only finder in framework runs, findings into the ledger |
| 7 | `documentation` | Human docs + curation of the long-lived `docs/` baseline behind form and truth gates |
| 8 | `delivery` | Conflict probe, PR with rendered body, CI fix loop, CP2 comment reconcile |

A bare number is a main-line step; a letter suffix is a variant at the same
stage — `1b`–`1e` are a sequence inside the UI branch, `2b`/`2c` optional
forks, `0a`/`0b`/`0c` alternative entry paths, and `4a`/`4b` mandatory
despite the letter. Skills with no number are not steps (see below). Inside
`specs/PROJ-<X>-<theme>/`, each subfolder carries the number of the skill
that writes it.

Brainstorming can decompose one broad seed into multiple PROJs; downstream
skills handle one PROJ at a time with sibling PROJs as dependency context.

The same skills serve two delivery tracks: the full in-repo build and a
**product discovery** track for pure product management — brainstorm,
wireframe, mockup, iterate with stakeholders, then hand a PRD to a
developer via Linear at Step 2, no codebase required. See
[docs/pm-chain.md](docs/pm-chain.md).

## The Agent Workflow Framework

After `checkpoint` (4a) seals CP1, the host-neutral phase runner drives the
execution phases unattended:

```bash
runner/run-phase.sh auto <proj-x> <theme>     # P0 → P5 → P6 → P7 → P8
# morning: read specs/morning-report-<date>.md, then review the PR (CP2)
```

What makes an overnight run trustworthy, in short: dual Claude + Codex lanes
per phase with exactly one writer orchestrator (the peer stays read-only),
`state.json`/`findings.json` as the only handoff, a persistent per-PROJ
worktree, evidence-based wave gates followed by an integration-focused PROJ
gate, provider-opposite cross-review on every artifact, budgeted context
bundles per role, the shared Ponytail minimalism ladder, hard P6/P7 gates
re-verified independently by the runner, and a stop policy that parks a run
on a failed writer, timeout, unsealed phase, or red gate instead of
continuing degraded. Reports and PR bodies are rendered from state + ledger
by template scripts, never hand-written.

Details: [docs/skill-chain.md](docs/skill-chain.md#framework-runs-agent-workflow-stage-1--stage-2)
for the full mechanics, [runner/README.md](runner/README.md) for the runner
itself, and `CONCEPT.md` for the full model and rationale. Stage 3+ of the
concept (P3 runner rework, deeper pre-mortem orchestration, Jira import, and
optional per-story worktree parallelism) is not built yet; the
producing-skill cross-review handoffs themselves are already wired.

## Outside the Chain

`cross-review` is not a chain step and is never routed to directly: it is
the symmetric opposite-provider review mechanism, invoked by the producing
skills. Concept, architecture, and plan reviews start automatically as soon as
their outputs are saved (and plan validation passes), before user approval or
handoff. Requirements, P6 QA, and P7 documentation also require review.
Findings of any severity trigger reconciliation and another review, up to three
automatic rounds; clean reviews stop early. Additional manually requested
rounds have no limit (`--round 4`, `--round 5`, and so on). Remaining
Critical/High findings block handoff; Medium/Low findings are reported or
deferred after the automatic rounds.
P6 uses six isolated discipline reviewers rather than one reviewer playing a
panel. A Codex-authored QA run fails closed when Claude is unavailable;
Claude-authored QA may fall back loudly to six Claude reviewers when Codex is
unavailable.

## Optional Skills

```text
5b_executing-large-model
bugfixing
refactor-dreamer
sonar-cli
supabase-local-dev
vibecoder
```

Each sits outside the main 0–8 flow — a drop-in Step 5 substitute for
frontier models (`5b`), a standalone repair workflow, or standalone tooling.
See [docs/skill-chain.md#optional-skills](docs/skill-chain.md#optional-skills)
for what each one does and when to reach for it.

Claude-specific experimental or personal skills are intentionally excluded.

## Repository Layout

```text
codex/skills/    Codex version of the chain
claude/skills/   Claude version of the chain
runner/          Host-neutral dual-lane phase runner, schemas, report templates, release-gate spikes
docs/            Human documentation for this repository
scripts/         Install and validation helpers
CONCEPT.md       The agent workflow framework specification
```

`AGENTS.md` is the only curated durable-context file. `CLAUDE.md` is
pointer-only and tells Claude to read `AGENTS.md`.

Framework helper scripts (`state.sh`, `ledger.mjs`, the compiler/injector,
gates, adapters) are byte-identical across their skill copies — `validate.sh`
enforces it.

## Install

Install the Codex skills:

```bash
./scripts/install-codex.sh
```

Install the Claude skills:

```bash
./scripts/install-claude.sh
```

Both scripts copy the bundled core chain and optional skills into the
default local skill directories. Framework runs additionally need the
Ponytail plugin on both providers — install commands and the mode/scoping
setup are in [docs/installation.md](docs/installation.md).

## Validate

```bash
./scripts/validate.sh          # structure, frontmatter, byte-identical helpers, schemas, syntax
runner/spike-dual-lane.sh      # Stage 1 release gate: live dual lanes, ledger guarantees, stop policy
runner/spike-stage2.sh         # Stage 2 release gate: bundles, injector, caps, cross-review, P7 gates
```

The validation script checks that the expected skill folders exist in both
trees, every skill has `SKILL.md` frontmatter, the byte-identical helper
set stays in sync, the schemas parse, every script passes a syntax check,
and the Wave Gate, ledger, worktree, plan-consistency, preflight/Biome,
cross-review, and registry behavior harnesses pass. The harnesses run
concurrently on their own fixtures; a full run takes about 40 seconds. The spikes are the release gates for the framework: they exercise
live provider lanes, the ledger's concurrency and reopen guarantees, and
every runner gate against stubbed failure fixtures.

## Inspirations

This repo was shaped by ideas from:

- [Get Shit Done](https://github.com/majiayu000/claude-skill-registry/tree/main/skills/data/get-shit-done)
- [Superpowers](https://github.com/obra/superpowers)
- [Ponytail](https://github.com/DietrichGebert/ponytail)
- [Alex Sprogis](https://www.alexsprogis.de/)

## License

MIT
