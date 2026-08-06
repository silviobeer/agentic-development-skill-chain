# Agentic Development Skill Chain

An opinionated skill chain for agentic software development, maintained in
parallel for Codex and Claude, plus an agent workflow framework that runs
the execution half of the chain unattended — dual provider lanes, machine-
readable state, a findings ledger, and hard gates instead of good
intentions.

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
| 1d | `ui-mockup` (UI req.) | HTML sitemap + per-screen mockups + implementation handoff |
| 1e | `concept-sync` (opt) | Reconcile iterated mockups back into the concept |
| 2 | `requirements-engineer` | PRDs: user stories, acceptance criteria, edge cases |
| 2b | `handoff-package` (opt) | Standalone zippable package for external experts |
| 2c | `review-reconcile` (opt) | Resolve PRD review gaps point by point |
| 3 | `architecture` | PROJ-level tech design across all PRDs |
| 4 | `writing-plans` | Wave-based implementation plans |
| 4a | `checkpoint` | CP1/CP2/bootstrap as structured reconcile loops with a decision log; CP1 seals `state.json` to `CP1:approved` |
| 4b | `setup` | P0 once per PROJ: branch, preflight, framework scripts into the repo, context bundles |
| 5 | `executing` | Implement wave by wave with TDD, wave gates, debt markers |
| 6 | `qa` | End-to-end QA; read-only finder in framework runs, findings into the ledger |
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

What makes an overnight run trustworthy:

- **Dual lanes, one writer.** Every phase runs a fresh Claude and Codex
  lane; exactly one may write, the peer is read-only. Handoff between
  phases happens only via `specs/PROJ-*/state.json` (written solely by
  `state.sh`) and the findings ledger `findings.json` (written solely by
  `ledger.mjs`).
- **Cross-model review.** Review routes to the provider OPPOSITE the
  artifact's author; a review gate is never satisfied by the model that
  authored the artifact. If one provider is down, the run degrades to a
  model-opposite reviewer — recorded and flagged, never silent.
- **Context bundles.** P0 compiles one canonical, token-budgeted context
  bundle per agent role from the curated `docs/` baseline (budget breach
  fails P0). Claude subagents get their bundle via a SubagentStart hook,
  Codex lanes read their projection file — same canonical hash on both.
  Micro-fixers and explore agents get nothing by design.
- **Minimalism ladder.** The third-party
  [Ponytail](https://github.com/DietrichGebert/ponytail) plugin, same
  version and mode on both providers (parity gated in preflight), scoped
  to code-writing roles only.
- **Hard gates.** P6 cannot seal with open Critical/High findings. P7
  cannot seal unless the docs pass the size caps (form), a docs
  cross-review actually ran during this P7 (evidence), and no blocking
  cross-review findings remain (truth). The runner re-verifies every gate
  independently after the seal.
- **Stop policy.** A failed writer, timeout, unsealed phase, or red gate
  parks the run: rescue branch for uncommitted work, state → `blocked`
  with the exact cause, rendered stop report. Reports and PR bodies are
  rendered from state + ledger by template scripts, never hand-written.

Details: [runner/README.md](runner/README.md),
[docs/skill-chain.md](docs/skill-chain.md), and `CONCEPT.md` for the full
model. Stage 3+ of the concept (P3 rework, pre-mortem call sites, Jira
import, worktree parallelism) is not built yet.

## Outside the Chain

`cross-review` is not a chain step and is never routed to directly: it is
the symmetric opposite-provider review mechanism, invoked inside P7 by the
documentation skill. It is required, not optional.

## Optional Skills

```text
refactor-dreamer
sonar-cli
```

`refactor-dreamer` is a separate long-run/overnight skill that scans a
grown codebase for architecture drift, refactor opportunities, and ADR
candidates, producing a `chain-input.md` that can feed back into the chain.

`sonar-cli` is a focused helper for configuring and running SonarScanner
CLI and triaging quality-gate data.

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
enforces it; `wave-gate.sh` is the per-platform exception.

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
set stays in sync, the schemas parse, and every script passes a syntax
check. The spikes are the release gates for the framework: they exercise
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
