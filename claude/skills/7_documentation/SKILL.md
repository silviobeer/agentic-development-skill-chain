---
name: documentation
description: "Create and curate human-readable project documentation after QA passes. Produces README.md, docs/PROJECT.md, docs/TECHNICAL.md, conditionally merges approved AGENTS.md candidates, keeps CLAUDE.md pointer-only, and in framework runs curates the long-lived docs/ baseline behind the P7 gates (chain check caps for form, cross-review for truth). Use when: (1) a feature has passed QA, (2) the user asks for app documentation, feature documentation, technical documentation, diagrams, data model notes, or data-flow explanation, (3) before handoff. Not for: writing PRDs, API reference generation, or first-run onboarding flows."
---

# Documentation

Show progress: run `bash ~/.claude/skills/5_executing/scripts/chain status --short <X>` (Codex: `~/.codex/skills/5_executing/scripts/chain`; `<X>` is this PROJ's number) when this skill starts and again in its final report, and show its line unchanged; if it prints nothing or fails, continue without it.

## External handoff inputs (conditional)

When `external-handoff.json` exists, use [the receiving input contract](../2e_handoff-refinement/references/input-contract.md) for requirement lookup instead of the local PRD paths below. Link the immutable baseline and explicit product responses with their version/hash provenance; keep engineering constraints and proposals distinguishable. Document implemented, verified behavior in this repository and name outstanding integration dependencies. Never edit received artifacts or present engineering assumptions, local seals, open PRs or unverified cross-repo behavior as accepted product truth.

## Artifact Language

From Requirements Engineer (Step 2) onward, write all newly authored artifacts
in English: PRDs, plans, decision records, handoff packages/prompts, findings,
worker reports, QA evidence summaries, documentation and PR descriptions.
Converse with the user in their language. Preserve identifiers, file paths,
verbatim source evidence and the product's required UI/localization language.
Concepts and discovery inputs may use another language; derive English artifacts
from them. Before CP1 approval, return non-English canonical PRD ACs to
Requirements Engineer for an approved English revision before downstream
verbatim copying. On resume after CP1 is sealed, preserve approved PRD/plan ACs
verbatim; a newer language policy alone must not reopen approval. New records
remain English. Change sealed canonical ACs only through an explicit user-
authorized revision and the owning review; never silently translate them.
External received ACs are quoted evidence: preserve their source language even
before CP1; the local-authoring language revision rule above does not authorize
translation or rewriting of an immutable package.


Run after QA passes for a PROJ-X. The goal is not a short changelog; the goal is curated documentation a human can use to understand:

- what the app does and which features exist
- how the main user workflows behave
- which technology choices matter
- how the data model, integrations, and data flows work
- what future agents must remember

Update only what needs updating, but do not keep the docs shallow when the feature or architecture needs explanation.

## Output Files

| File | Role | Update trigger | Length budget |
|---|---|---|---|
| `README.md` | App on-ramp: what it is, how to run it, where deeper docs live | First PROJ, dependency/setup change, deployment change, or explicit user request | <= 80 lines |
| `docs/PROJECT.md` | Human feature guide: implemented capabilities, user workflows, status, links to PRDs | Always when QA passes | grows with PROJs; concise but useful |
| `docs/TECHNICAL.md` | Technical reference: architecture, data model, data flows, integrations, deployment, gotchas | Architecture/data/dependency/agent-note changes, or explicit user request | as long as needed |
| `AGENTS.md` | Durable agent context for all future coding sessions | >= 1 approved candidate from progress.md | <= 40 non-blank lines hard cap |
| `CLAUDE.md` | Pointer-only Claude entry file; must tell Claude to read `AGENTS.md` | Missing, or contains durable rules instead of only a pointer | <= 5 lines; no curated rules |

No per-feature documentation files by default. The PRDs under `specs/PROJ-<X>-<theme>/2_PRDs/` remain the detailed requirement source; link to them instead of copying acceptance criteria.

## Mandatory Delegation Contract

When Claude `Agent` subagents are available and permitted, workers own all
product-source, test, defect-fix, and human-documentation edits this workflow
requires. The lead owns decomposition, dispatch, integration, deterministic
verification, gates, and operational records. Dispatch independent tasks with
disjoint file ownership in parallel; serialize dependent or overlapping work.
Send integration corrections to a follow-up worker. The lead may edit covered
files locally only when delegation is unavailable or prohibited, and must report
the reason explicitly.

## Decomposed PROJ Handling

Documentation updates the completed PROJ while preserving the larger decomposition map:

- `docs/PROJECT.md` should show how this PROJ fits sibling PROJs when the concept has `Decomposition Context`.
- Refresh only the current PROJ's detailed section; keep sibling sections intact.
- If this PROJ introduces or consumes shared design language, document the canonical design file and which sibling PROJs it applies to.
- `docs/TECHNICAL.md` should document cross-PROJ contracts only when they are source-backed by concept, architecture, plans, or implementation.
- Do not describe unbuilt sibling PROJs as shipped capabilities.

## Input

Read in this priority order. Structured data first; raw reconstruction only as fallback.

**Structured inputs, filled by Skills 4/5/6:**

1. `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md`
   - `### Wave N Gate — PASSED` blocks: authoritative wave completion proof, including the `Stories:` line (shipped user stories)
   - `## QA Results`: QA summary and residual risk
   - `## PROJ Retrospective`: implementation lessons and durable observations
   - `## AGENTS.md Candidates`: proposed durable agent rules awaiting approval
   - Framework runs: QA's read-only finder wrote its `QA Results`, `PROJ Retrospective` and candidates to `5_progress/qa-finder-<ts>.md` (path: `chain state get <X> <theme> .qa.finder_report`) instead of progress.md; read that file for those three sections.
2. `specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md`
   - app/feature purpose, target user, in-scope/out-of-scope boundaries
3. `specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-*.md`
   - title, purpose paragraph and `## User Story` heading lines only (see step 1.3)
4. `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md`
   - architecture, data model, data flows, cross-cutting decisions
5. `src/features/*/agent.md`
   - non-obvious gotchas surfaced during implementation
6. `package.json` at `BASE_SHA` and `HEAD`
   - dependency and script deltas for setup/technical docs

**Fallback only if structured inputs are absent:**

7. `3-4_plan/PROJ-<X>-wave-*-plan.md` story headings, for PROJs gated before the `Stories:` line existed
8. `git log --oneline --grep="PROJ-<X>" --reverse`
9. focused code structure scan

Do not re-derive what structured inputs already provide. If a Wave PASSED block lists shipped stories, treat that as canonical.

## Claude Adaptation

This Claude skill uses the Codex documentation skill as the behavioral source of truth. Keep gates, output structure, diagrams, content ownership, and `AGENTS.md` merge behavior aligned with the Codex copy. Claude-specific differences are limited to tool invocation and the pointer-only `CLAUDE.md` file:

- Use project-root `AGENTS.md` for durable agent context.
- Keep project-root `CLAUDE.md` pointer-only. It must reference `AGENTS.md` as required reading and must not contain curated rules.
- Ask the user before merging any `AGENTS.md` candidate unless the current user request explicitly authorizes automatic merging.
- Apply the mandatory delegation contract whenever Claude `Agent` subagents are available and permitted.
- Keep documentation edits scoped to triggered files.

## Documentation Standard

Write for a human maintainer or product owner who did not implement the feature.

- **Curated, not exhaustive:** explain the current truth of the app; link to PRDs for detailed acceptance criteria.
- **Feature-first:** `PROJECT.md` should answer "what can users do now?" before it talks about implementation.
- **Technical clarity:** `TECHNICAL.md` should explain architecture, technology choices, data model, data flows, deployment, and operational gotchas.
- **Diagrams when useful:** use Mermaid diagrams for system context, data model, state transitions, and critical data flows when the source material supports them.
- **Source-backed:** never invent entities, tables, services, queues, permissions, or flows. If a fact is inferred from code, say so briefly.
- **Incremental curation:** update stale sections, remove contradicted statements, and keep sibling PROJs intact.

## Context Economy

Documentation arrives late in the chain. Keep the main context focused on `progress.md`, the current doc diff, and any user approvals.

- Read `progress.md` first to decide which outputs are triggered.
- Load concept, PRDs, architecture, wave plans, and source files only for the triggered output that needs them.
- If delegation is allowed, assign independent harvest tasks to subagents; otherwise do focused local reads.
- Keep long PRDs, architecture files, screenshots, and raw logs out of the final answer.

## Workflow

### 1. Collect documentation inputs

Start with `5_progress/PROJ-<X>-progress.md`. Then collect only the extra inputs needed for triggered outputs:

1. **Feature purpose and boundaries:** read the concept file if `PROJECT.md` or `README.md` needs human-facing purpose/scope text.
2. **Shipped stories:** the `Stories:` line of each `### Wave N Gate — PASSED` block. Fall back to wave-plan headings matching `## PROJ-<X>-PRD-<Y>-US-<Z>:` only for PROJs gated before this line existed.
3. **Feature behavior:** read each PRD's title, purpose paragraph and the `## User Story` heading lines only (`grep -n '^## \|^# ' <prd>`, then targeted `sed -n` ranges). Open a full story only when PROJECT.md needs a workflow it cannot state from the heading. Do not paste acceptance criteria.
4. **Technical structure:** read architecture and relevant `agent.md` files when `TECHNICAL.md` triggers.
5. **Dependency delta:** compare `package.json` at `BASE_SHA` to `HEAD` using structured JSON over `dependencies` and `devDependencies`.
6. **Runtime/deployment facts:** inspect package scripts, config files, env examples, and deployment notes only when README or TECHNICAL needs them.

**Trigger evaluation:**

- `PROJECT.md`: always true after QA passes
- `README.md`: first PROJ, dependency/setup/deployment delta, missing README, or explicit request
- `TECHNICAL.md`: architecture/data-flow/data-model/integration/dependency/agent-note change, missing technical doc, or explicit request
- `AGENTS.md`: `## AGENTS.md Candidates` has at least one `[PROPOSED]` entry
- `CLAUDE.md`: missing, or contains durable rules instead of only a pointer to `AGENTS.md`

**Missing-sections fallback:** if `## PROJ Retrospective` or `## AGENTS.md Candidates` is absent, proceed anyway and note the degraded input path in the final summary.

Only proceed to sections whose trigger fires.

### 2. Update `docs/PROJECT.md`

Always runs. This is the human feature guide, not a terse release log.

**Required structure:**

````markdown
# Project - Features

**Last updated:** YYYY-MM-DD
**Features implemented:** <count>

---

## PROJ-<X>: <theme>

**Status:** <development | QA-passed | production>
**Purpose:** <one-sentence user/business goal from concept>
**Scope:** <what is included and intentionally excluded>

### Capabilities

- <user-facing thing the app can now do>
- <another capability>

### Primary Workflow

1. <human workflow step>
2. <human workflow step>
3. <outcome>

```mermaid
flowchart LR
  A[Start] --> B[Key user action]
  B --> C[System response]
  C --> D[Result]
```

### User Stories Implemented

- PROJ-<X>-PRD-1-US-1: <title>
- PROJ-<X>-PRD-1-US-2: <title>

### Notes

- **PRDs:** [PRD-1](../specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-1-<desc>.md)
- **QA:** <pass/bugs/residual-risk summary from QA Results>
- **Known limits:** <only if source-backed>
````

Guidelines:

- New PROJs append. Existing PROJs get only their own section refreshed.
- Include a Mermaid workflow only for meaningful multi-step behavior; skip it for trivial backend or setup-only changes.
- Keep feature text understandable to non-engineers.
- Do not duplicate detailed acceptance criteria, edge-case lists, or implementation plans.

### 3. Update `README.md`

Runs conditionally. README is the front door, not the technical deep dive.

**Required structure:**

````markdown
# <Project Name>

> <one-sentence app purpose>

## What It Does

- <top-level capability>
- <top-level capability>
- <top-level capability>

## Quick Start

```bash
<install command>
<dev command>
```

## Tech Stack

- <framework> - <one-line purpose>
- <database/auth/styling/deployment> - <one-line purpose>

## Documentation

- [Features](docs/PROJECT.md) - human feature guide and workflows
- [Technical](docs/TECHNICAL.md) - architecture, data model, data flows, deployment, gotchas
- [AGENTS.md](./AGENTS.md) - durable conventions for AI-pair coding
````

Guidelines:

- Keep it short enough to scan.
- Mention setup requirements, env files, and scripts only at the level needed to run the app locally.
- Avoid duplicating `TECHNICAL.md`; link to it for architecture/data details.

### 4. Update `docs/TECHNICAL.md`

Runs conditionally. This is the maintainers' technical map of the app.

**Required structure:**

````markdown
# Technical Reference

**Last updated:** YYYY-MM-DD

## System Overview

<short explanation of runtime shape and major modules>

```mermaid
flowchart LR
  User[User] --> App[App/UI]
  App --> API[API or server actions]
  API --> DB[(Database)]
```

## Architecture

<high-level architecture from PROJ architecture files>

## Technology Choices

| Area | Choice | Why it matters |
|---|---|---|
| Frontend | <tool> | <reason> |
| Data | <tool> | <reason> |

## Data Model

<entities, relationships, ownership, important constraints>

```mermaid
erDiagram
  USER ||--o{ ITEM : owns
```

## Data Flows

### <Flow Name>

<when this flow happens and why>

```mermaid
sequenceDiagram
  actor User
  participant App
  participant API
  participant DB
  User->>App: Action
  App->>API: Request
  API->>DB: Read/write
  API-->>App: Response
```

## Integrations and External Services

<APIs, auth providers, storage, payment, queues, model providers, email, analytics>

## Directory Structure

```text
src/
  app/       - <what lives here>
  features/  - <what lives here>
  lib/       - <what lives here>
```

## Dependencies

<runtime and dev dependencies with purpose, especially newly introduced ones>

## Deployment and Runtime

<provider, build command, env-var overview, persistence/runtime constraints>

## Operational Notes and Gotchas

<source-backed notes from agent.md, QA, post-wave notes, and retrospective>
````

Guidelines:

- Prefer Mermaid diagrams over prose when they reduce ambiguity.
- Include at least one diagram when `TECHNICAL.md` is created from scratch and architecture/data-flow information exists.
- Use `flowchart`, `sequenceDiagram`, `erDiagram`, or `stateDiagram-v2` according to the source material.
- Do not create fake diagrams from guesses. If the data model is absent, write "No persistent data model documented yet" rather than inventing one.
- Update stale diagrams when the underlying architecture changes.
- Keep technology explanations practical: what it is used for, why it matters, and where to find it in the repo.

### 5. AGENTS.md merge

Runs only if `## AGENTS.md Candidates` (in progress.md, or the QA finder report in framework runs) has `[PROPOSED]` entries.

**Algorithm:**

1. Parse every `[PROPOSED]` line from progress.md's candidates section. Each line has a stable ID, such as `AGENTS-PROJ1-QA-003`.
2. For each candidate, ask the user directly:
   - Approve
   - Reject
   - Approve with edit
   - Skip
3. For each approved or edited candidate:
   - Append it to project-root `AGENTS.md` under an appropriate short heading.
   - Prefix the line with its ID as a comment anchor: `<!-- AGENTS-PROJ1-QA-003 -->`.
   - In progress.md, flip `[PROPOSED]` to `[MERGED]` by ID. Never delete the candidate line.
4. Enforce the 40-line hard cap on `AGENTS.md`.
   - Count non-blank lines, including headings.
   - If over 40, ask the user which old entries to remove. Do not delete automatically.
5. Rejected candidates are marked `[REJECTED]` in progress.md to prevent re-proposal.

Never edit `AGENTS.md` without explicit approval per entry. The user owns this file; Skill 7 only facilitates.

### 6. CLAUDE.md pointer

Runs if `CLAUDE.md` is missing or contains durable rules.

`CLAUDE.md` must stay a tiny pointer file. It should not be curated, should not receive QA candidates, and should not duplicate `AGENTS.md`.

Allowed content:

```markdown
# Claude Instructions

Must read and follow [AGENTS.md](./AGENTS.md) before making changes. All durable agent instructions are curated in AGENTS.md only.
```

If an existing `CLAUDE.md` contains additional durable rules, move proposed durable rules through the normal `AGENTS.md` candidate flow instead of preserving them in `CLAUDE.md`.

### 7. Curated-context curation + P7 gates (framework runs)

Runs only in framework runs — `specs/PROJ-<X>-<theme>/state.json` exists
and P7 is the running phase. Standalone documentation requests skip this
section and the seal in section 8.

This is the curation step of CONCEPT.md §4 P7: the curated docs under
`docs/` (PRODUCT, ARCHITECTURE, GUIDELINES, DESIGN-SYSTEM, components,
review-checklist, security-baseline, test-conventions —
created by the intake baseline) are supplied according to role to future
implementers and reviewers. They are updated HERE, gated on form and truth, and nowhere
else. If no intake baseline exists yet, curate only the files that do
exist — `chain check caps` warns on missing baseline files instead of
failing.

**7a. Curate the long-lived docs** (judgment first, gates after):

1. Merge surviving decisions from `specs/.../3-4_plan/PROJ-<X>-architecture.md` and
   `decisions.md` entries with lasting value into `docs/ARCHITECTURE.md`.
   Start from every `**Changes baseline:**` line of the PROJ architecture:
   each names a section to rewrite. `docs/ARCHITECTURE.md` describes the
   system as it is NOW in its sections (Stack · System shape · Data
   ownership · Invariants) — edit the affected section in place, never
   append a per-PROJ or "built in PROJ-n" section; that history is what
   `docs/DECISIONS.md` and git are for. Where the build deviated from the
   plan, the section states what was built and the DECISIONS.md entry says
   "planned X, built Y, because ..." — never silently overwrite the baseline.
   A baseline from before these four sections (an older intake) keeps its
   headings: rewrite the section that holds the affected statement; when
   none fits, add the missing one of the four sections — never a per-PROJ one.
   Entries with lasting WHY (rejected alternatives, constraints, trade-offs)
   are appended to `docs/DECISIONS.md` — append-only, one `D-<X>-<NN>`
   entry each (Decision, Context, Alternatives, Status), `ARCHITECTURE.md`
   links by ID instead of restating the WHY. When a decision replaces an
   earlier one, set the old entry's Status to `superseded by D-…`; never
   delete or rewrite it. Create the file on first use.
2. Migrate ground-file assumptions this PROJ validated into
   `docs/ARCHITECTURE.md`/`docs/GUIDELINES.md` and DELETE them from
   `ground-file.md` — the ground file holds ONLY what docs/ does not
   (redundancy rule §5).
3. Update `docs/PRODUCT.md` for new user-facing scope or terms.
4. Route QA proposals using the [trap test](../../../CONCEPT.md#trap-test-and-rule-placement):
   target-state rules go in `docs/GUIDELINES.md` by topic; project-specific traps
   or hard limits go in its `## Traps` (≤10 top-level list entries, each
   `Don’t X → instead Y — why it happens here`). Project-specific quality checks
   go in `docs/review-checklist.md` § Antipatterns with detection signal and severity;
   existing losing patterns go in § Known Debt (do not re-flag, do not spread).
   Generic quality findings use the existing QA catalog, not a copied project catalog.
   Chain-owned generic Don’ts stay only in role manifests; never duplicate them in Traps.
   At either cap, curate rather than append. Durable project-wide rules still go
   through the AGENTS.md candidate pipeline (section 5), never directly.
5. Register new components in `docs/components.md`.
6. Curate `src/**/agent.md`: keep what this PROJ confirmed, delete what
   it outdated, promote project-wide entries to AGENTS.md candidates.

**7b. Record authorship** — the truth gate must know who curated:

```bash
bash scripts/chain state set <X> <theme> '.authorship["docs-delta"]' \
  '{"author_provider":"<claude|codex>","author_model":"<model>"}'
```

**7c. FORM gate:** `bash scripts/chain check caps` — exit != 0 means a
cap is breached (PRODUCT <= 30 non-blank lines, ARCHITECTURE <= 200
lines, DESIGN-SYSTEM <= 80, GUIDELINES <= 120 with <= 10 Traps entries,
review-checklist <= 80, security-baseline and test-conventions <= 60
lines, each agent.md <= 100 lines, AGENTS.md <= 40 non-blank lines).
Shrink by curating — move detail into `docs/architecture/`, delete stale
statements — and re-run until exit 0. Never delete true load-bearing
statements just to fit the cap: the truth gate flags cap-gaming.

**7d. TRUTH gate (BLOCKING):**

The artifact list is EVERY doc-layer file this PROJ touched — curated
baseline, generated docs, AGENTS.md, and curated agent.md files — not a
fixed subset. Anything skipped here enters future context bundles
unchecked.

```bash
BASE_SHA="$(bash scripts/chain state get <X> <theme> .base_sha)"
ARTIFACTS="$(git diff --name-only "$BASE_SHA"..HEAD -- \
  docs/ AGENTS.md README.md 'src/**/agent.md' | tr '\n' ' ')"
# fallback when nothing doc-layer changed but curation ran anyway:
[ -n "$ARTIFACTS" ] || ARTIFACTS="docs/ARCHITECTURE.md docs/PRODUCT.md docs/GUIDELINES.md docs/components.md"
bash scripts/chain review docs <X> <theme> \
  --artifacts $ARTIFACTS \
  --author-key docs-delta \
  --diff-base "$BASE_SHA" \
  --diff-paths . ':(exclude)specs/**' ':(exclude)**/*.test.*' \
    ':(exclude)**/*.spec.*' ':(exclude)tests/**' ':(exclude)e2e/**' \
  --round 1
```

- No findings and exit 0 → proceed to section 8.
- Findings of any severity → fix the docs within approved scope, mark each fix
  (`bash scripts/chain findings set-status <X> <theme> <id> fixed <commit>`
  — an unmarked fix keeps blocking; a false "fixed" is reopened on
  re-report), re-run 7c, then automatically run `--round 2` and, if findings
  remain, `--round 3`. Follow `cross-review`'s three-round automatic limit; exit 0 with
  Medium/Low findings still triggers the next available round.
- After round 3 → remaining Critical/High findings stop the phase: escalate
  unresolved IDs. Defer remaining Medium/Low as debt and proceed to section 8
  only when no blockers remain.
- exit 1 → infrastructure failure: also a stop condition — the truth
  gate did not run, the phase must not seal without it.

The runner independently re-verifies both gates after the seal — including
that a docs cross-review actually RAN during this P7 (a skipped review
is not a clean review); sealing past a red gate parks the run.

### 8. Git commit + P7 seal

One commit for the documentation update:

```text
docs(PROJ-<X>): Update project documentation
```

If `AGENTS.md` was merged or `CLAUDE.md` was normalized to the pointer, include those changes in the same commit. Curated `docs/` changes from section 7 belong in the same commit — they are part of the PR's "doc changes" section.

Framework runs: seal the phase afterwards — `bash scripts/chain state transition <X> <theme> P7 done`. Never seal while 7c or 7d is red.

## Content Ownership

| Info | Lives in |
|---|---|
| "What does this app do?" | `README.md` summary + `docs/PROJECT.md` feature guide |
| "How do I run it?" | `README.md` |
| "Which features exist and how do users use them?" | `docs/PROJECT.md` |
| "What are the detailed ACs of feature X?" | Linked PRD |
| "Why did we choose this architecture or dependency?" | `docs/TECHNICAL.md` |
| "What is the data model?" | `docs/TECHNICAL.md` |
| "How does data move through the system?" | `docs/TECHNICAL.md` with Mermaid flow/sequence diagrams |
| "What should future agents always remember?" | `AGENTS.md`, after user approval |
| "Where should Claude look for durable rules?" | `CLAUDE.md` pointer to `AGENTS.md` |
| "What bugs remain?" | `docs/PROJECT.md` QA note if source-backed |

## Rules

- English for all generated docs, even if the conversation is German.
- Human-readable first; implementation details only where they explain behavior or maintenance.
- Do not duplicate PRDs, architecture plans, or QA logs; summarize and link.
- Prefer source-backed statements over confident reconstruction.
- Keep diagrams valid Mermaid and small enough to read.
- No emojis unless the user explicitly asks.
- Do not fabricate setup commands, environment variables, tables, queues, services, or integrations.

## When to Run

- After Step 6 QA passes for a PROJ-X.
- When the user explicitly asks for documentation, feature docs, technical docs, diagrams, data model explanation, or data-flow explanation.

Legacy PROJ folders: see `0_chain-guide/references/legacy-layout.md`.
