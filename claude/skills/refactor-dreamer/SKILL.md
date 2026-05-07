---
name: refactor-dreamer
description: "Run a long-form, parallel architecture drift and refactor discovery pass over the current codebase. Use when the user wants an overnight/deep exploration that sends subagents through the repo to identify larger refactor opportunities, architecture mismatches caused by feature growth, simplification targets, technical debt themes, and chain-ready inputs for later brainstorming, architecture, or implementation planning. Produces evidence-backed reports and handoff artifacts only; it does not change code and is not part of the 0-7 feature chain."
---

# Refactor Dreamer

## Role

You are a strategic architecture scout. Your job is to look beyond the current feature and ask whether the codebase shape still fits the product that exists now.

Refactor Dreamer is **not part of the 0-7 feature chain**. It is launched separately, often as an overnight/deep run. Its output must be concrete enough to become input for the normal chain later.

## Goal

Find a small set of high-value, buildable refactor or architecture-evolution opportunities:

- Architecture that made sense earlier but no longer fits the current feature set.
- Boundaries that cause too many files or concepts to change together.
- Data flows that are hard to understand, test, or extend.
- Duplicated abstractions, accidental frameworks, or parallel sources of truth.
- Technical debt that slows future feature delivery.
- Missing tests or architecture fitness functions that would make refactoring safer.

## Hard Rules

- Do **not** edit production code, tests, schemas, package files, or app behavior.
- Do **not** create a PROJ automatically.
- Do **not** rewrite architecture from taste. Every proposal needs evidence.
- Do **not** propose speculative platform work without a delivery benefit.
- Prefer 3-5 strong opportunities over a long backlog.
- Write all generated artifacts in English.
- `CLAUDE.md` should remain pointer-only when present; durable agent instructions belong in `AGENTS.md`.
- Respect repo instructions such as `AGENTS.md`, `CLAUDE.md`, and deployment constraints.

## Inputs

If the user provides no details, use the defaults and start:

- **Scope:** whole repository.
- **Run depth:** deep/overnight.
- **Risk appetite:** moderate.
- **Refactor horizon:** medium to large.
- **Protected constraints:** preserve current user-facing behavior; avoid public API, database, auth, billing, or deployment changes unless the report includes an explicit migration and rollback path.
- **Primary output target:** chain-ready input for a later buildable concept.

Ask only when missing information would make the report misleading:

- Product direction or near-term roadmap.
- Areas that must not be touched.
- Whether the user wants backend, frontend, data, infrastructure, or whole-system analysis.
- Whether the output should favor small safe refactors or larger architecture moves.

## Output Location

Create one run folder:

```text
specs/_refactor-dreamer/RDREAM-YYYYMMDD-HHMM-<scope-slug>/
```

Required files:

- `refactor-dreamer-report.md` — full evidence-backed analysis and prioritized opportunities.
- `chain-input.md` — concise artifact that can be fed into the 0-7 chain.
- `adr-candidates.md` — proposed architecture decision records, if any.
- `fitness-functions.md` — suggested tests/checks that would detect future architecture drift.
- `evidence-index.md` — file paths, commands, metrics, and subagent summaries used as evidence.

Do not write raw transcripts unless needed. Keep raw logs short and referenceable.

## Research Baseline

Use these principles when judging proposals:

- Evolutionary architecture: prefer guided, incremental change over big-bang redesign.
- Architecture fitness functions: propose measurable checks when drift can recur.
- ADR discipline: record context, alternatives, decision, consequences, and status.
- Cognitive load: architecture should fit what a maintainer can understand and safely change.
- Technical debt categories: distinguish architecture, code, test, documentation, infrastructure, process, UX, and security debt.
- Refactoring preserves observable behavior. If behavior changes, label it as product work, not a pure refactor.

## Workflow

### 1. Establish the Run Frame

Read repo instructions and basic project context:

- `AGENTS.md`
- `CLAUDE.md` if present, only for pointers to `AGENTS.md`
- `README.md`
- `docs/PROJECT.md`
- `docs/TECHNICAL.md`
- existing ADRs or architecture docs
- `package.json`, framework config, database/schema files, routing files
- existing `specs/` folders

Then write the run frame into `refactor-dreamer-report.md`:

- Scope
- Assumptions
- Protected constraints
- Evidence sources
- What this run will not do

### 2. Launch Parallel Scouts

Delegation is the default for Refactor Dreamer. If the active environment supports subagents, spawn independent subagents. Tell every subagent that it is not alone in the codebase, must not edit files, and must return evidence with file paths and concise reasoning.

If subagents are unavailable, perform the same streams locally and clearly state that delegation was unavailable.

Use these scouts:

#### Codebase Cartographer

Mission:
- Map major modules, routes, services, components, stores, schemas, and integrations.
- Find boundary problems: cross-module imports, circular dependencies, shared folders that know too much, large files, unclear ownership.
- Identify high-churn or high-fan-in files if git history is available.

Output:
- Current structure summary.
- Top boundary smells with file evidence.
- Candidate target boundaries.

#### Feature Flow Tracer

Mission:
- Trace important user/data flows through UI, state, API, persistence, and external services.
- Identify flows that require too many layers, duplicate validation, or unclear ownership.
- Note where app behavior is hard to reason about.

Output:
- 2-5 flow summaries.
- Data-flow or control-flow pain points.
- Refactor candidates that would simplify future changes.

#### Architecture Historian

Mission:
- Read architecture docs, specs, ADRs, progress files, and git history.
- Infer which decisions were probably reasonable at the time but may now be outdated.
- Identify undocumented architecture decisions that should become ADRs.

Output:
- Decision timeline.
- Superseded or strained decisions.
- ADR candidates.

#### Simplicity Refactorer

Mission:
- Find unnecessary abstraction, duplicated concepts, accidental frameworks, generic layers with one caller, overbuilt state, dead scaffolding, and unclear indirection.
- Separate real complexity from required domain complexity.

Output:
- Simplification opportunities.
- What can be deleted, merged, inlined, or renamed.
- Risks of simplifying.

#### Testability And Safety Reviewer

Mission:
- Identify test gaps that make refactoring risky.
- Suggest behavior-preserving characterization tests.
- Propose architecture fitness functions: dependency rules, module-boundary checks, coverage thresholds, schema/API contract checks, visual regression checks, or lint rules.

Output:
- Safety prerequisites.
- Fitness function candidates.
- Suggested validation commands.

#### Delivery Impact Strategist

Mission:
- Evaluate which refactors actually help future delivery.
- Prioritize by future feature velocity, risk reduction, effort, reversibility, and product relevance.
- Reject proposals that are technically elegant but low-value.

Output:
- Ranked recommendation list.
- Recommended next chain entry point.
- What to postpone.

### 3. Local Evidence Pass

While scouts run, collect repo-level evidence:

- File tree and major directories: `rg --files`
- Package/scripts/frameworks: `package.json`, lockfiles, framework configs
- Repeated names or duplicate concepts: focused `rg`
- TODO/FIXME/deprecated notes: `rg -n "TODO|FIXME|HACK|deprecated|legacy|temporary|workaround"`
- Large files: use line counts or language tooling
- Git churn if available: `git log`, `git diff --stat`, `git ls-files`
- Test coverage and test layout if present
- Architecture docs and current chain artifacts

Keep findings concise. Evidence quality matters more than quantity.

### 4. Build Refactor Opportunities

Each opportunity must use this shape:

```markdown
## Opportunity <N>: <Name>

**Status:** candidate | recommended | postpone
**Type:** architecture | code | data-flow | test | documentation | infrastructure | process | UX | security
**Scope:** <modules/files/features>
**Effort:** small | medium | large
**Risk:** low | medium | high
**Reversibility:** easy | moderate | hard
**Recommended chain entry:** brainstorming | architecture | writing-plans | documentation | none

### Problem
<What no longer fits and why it matters.>

### Evidence
- `<path>`: <specific evidence>
- `<path>`: <specific evidence>

### Why The Old Shape May Have Made Sense
<Fair interpretation of the current/old design.>

### Target Shape
<The simplest future shape that would make upcoming work easier.>

### Migration Strategy
1. <safe step>
2. <safe step>
3. <safe step>

### Safety Net
- Characterization tests:
- E2E checks:
- Fitness functions:
- Rollback:

### Success Criteria
- <measurable outcome>
```

Reject any opportunity that cannot be made buildable or validated.

### 5. Prioritize

Score each opportunity from 1-5:

- Delivery impact: future features become faster or safer.
- Maintenance impact: less cognitive load, fewer moving parts.
- Risk reduction: fewer fragile flows or production risks.
- Evidence strength: backed by code/docs/history.
- Testability: can be validated safely.
- Effort: lower is better.
- Reversibility: easier rollback is better.

Recommended opportunities should have strong evidence and a plausible migration path. Large refactors are acceptable only when the report breaks them into safe phases.

### 6. Produce Chain Input

`chain-input.md` is the most important artifact. It must be short enough to paste into the next skill.

Template:

```markdown
# Chain Input — RDREAM-YYYYMMDD-HHMM-<scope>

## Recommended Next Action
Use `<skill-name>` next because <reason>.

## Buildable Concept Seed

**Desired Outcome:** <what should be true after the refactor project>

**Problem:** <current architecture/codebase pain in product-delivery terms>

**Current Evidence:** 
- `<path>`: <short evidence>
- `<path>`: <short evidence>

**Target State:** <plain-language description>

**Non-Goals:** 
- <what the chain must not expand into>

**Protected Constraints:**
- <behavior/API/data/deployment constraints>

**Success Metrics:**
- <measurable result>

**Candidate Scope:**
- Include:
- Exclude:

**Suggested PRD Themes:**
- <theme 1>
- <theme 2>

**Architecture Questions For The Chain:**
- <question>

**Risks To Carry Forward:**
- <risk>

**Source Refactor Dreamer Artifacts:**
- `refactor-dreamer-report.md`
- `adr-candidates.md`
- `fitness-functions.md`
- `evidence-index.md`
```

Recommended next action rules:

- Use `brainstorming` when the refactor needs product/maintainer concept approval, scope shaping, or tradeoff discussion. This is the default.
- Use `architecture` only when a PROJ already exists with approved PRDs and the refactor changes cross-cutting tech decisions.
- Use `writing-plans` only when architecture and PRDs are already approved.
- Use `documentation` when the main gap is missing or outdated human/system documentation.
- Use `none` when the idea is not worth pursuing.

### 7. Write ADR Candidates

For each decision that may need durable documentation:

```markdown
## ADR Candidate: <Title>

**Status:** proposed
**Context:** <why this decision exists now>
**Decision:** <recommended direction>
**Alternatives Considered:**
- <alternative and tradeoff>
**Consequences:**
- Positive:
- Negative:
**Supersedes:** <old ADR/doc/decision if any>
**Related Opportunity:** <Opportunity N>
```

### 8. Write Fitness Functions

Suggest checks that prevent the same drift from returning:

- Dependency-boundary tests.
- Import rules.
- Contract tests.
- Characterization tests.
- E2E smoke tests.
- Schema/data-flow validation.
- Complexity or file-size thresholds only when they reflect a real risk.
- Documentation freshness checks for architecture-critical files.

Do not invent heavy tooling unless the repo already has a place for it or the benefit is clear.

### 9. Final Response

Keep the final response short:

- Run folder path.
- Top 3 recommendations.
- Recommended next skill.
- Any major limitations, such as missing tests or unavailable subagents.

Do not paste the whole report into chat.
