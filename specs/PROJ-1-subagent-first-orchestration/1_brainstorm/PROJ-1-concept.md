# PROJ-1 Concept - Subagent-First Orchestration

## Status

Approved concept

## Feature Seed

Make every code- or documentation-writing workflow encourage agents to act as
orchestrators by delegating edits to subagents.

## Decomposition Context

- Original broader seed: strengthen subagent use throughout implementation.
- Approved project map: one cross-cutting PROJ covering all applicable write-capable skills.
- This PROJ's role: establish one consistent subagent-first behavior across Codex and Claude.
- Sibling PROJs: none.
- Depends on: none.
- Blocks: none.
- Scope intentionally assigned to another PROJ: none.

## Project Context

- Existing system: a parallel Codex and Claude 0-to-8 skill chain plus optional workflows and an unattended phase runner.
- Relevant constraints: keep both provider chains aligned except for tool-specific wording; preserve `AGENTS.md` as the only curated durable-context file; run `./scripts/validate.sh` before publishing.
- Prior related specs: existing execution and QA skills already contain partial delegation guidance, but the strength and fallback behavior are inconsistent.

## Problem And Goal

Write-capable skills sometimes allow the lead agent to implement locally even
when subagents are available. This consumes the lead's context, weakens
parallelism, and makes the lead behave like an implementer rather than the
orchestrator responsible for the whole workflow.

The goal is to make covered edits worker-owned whenever delegation is
available, while leaving coordination, integration, verification, gates, and
operational records with the lead.

## Primary Users And Scenarios

- A Codex lead running a covered skill interactively delegates implementation or documentation edits and retains orchestration duties.
- A Claude lead running the same skill follows equivalent behavior using Claude-specific delegation tools.
- An unattended runner writer lane acts as the phase orchestrator and delegates covered edits to its workers.
- A lead whose host lacks or prohibits delegation uses a visible local fallback instead of blocking the workflow.

## Current Workflow Or Pain

- Claude execution already mandates broad delegation, while Codex execution permits local implementation when delegation is not allowed and otherwise treats delegation more narrowly.
- Bug fixing, QA fix handling, documentation, delivery, exploratory coding, and frontend design do not express one consistent mandatory contract.
- Local fallbacks are not consistently surfaced to the user.
- A lead may absorb implementation logs and source context that workers could own, reducing its ability to coordinate the complete run.

## Success Criteria

- Every covered Codex and Claude skill explicitly requires delegation of covered edits whenever subagents are available.
- Every covered skill defines the lead as the owner of decomposition, dispatch, integration, deterministic verification, gates, and operational records.
- Independent tasks with disjoint ownership are dispatched concurrently; dependent or overlapping work is serialized.
- Integration corrections are delegated as follow-up fix tasks rather than edited directly by the lead.
- Every covered skill permits local editing only when delegation is unavailable or prohibited and requires the reason to be reported explicitly.
- Codex and Claude instructions remain behaviorally aligned while using platform-appropriate tool wording.

## Scope

### In Scope

- `frontend-design`
- `executing`
- `bugfixing`
- QA fix orchestration
- `documentation`
- `delivery`
- `vibecoder`
- Interactive and unattended runner-driven runs
- Product code, tests, defect fixes, exploratory code, and human documentation

### Out Of Scope

- Bootstrap scaffolding and configuration edits
- UI mockup artifacts
- Concepts, PRDs, architecture documents, and implementation plans
- State, findings, progress logs, generated reports, and PR metadata
- New hooks, validators, evals, or a shared orchestration framework

### Later

- Automated enforcement if instruction-only guidance proves insufficient
- Metrics comparing delegation compliance, context use, latency, or cost

## Selected Direction

Add a concise mandatory delegation contract directly to every covered skill.
Keep each installed skill self-contained instead of introducing a shared
contract file. Preserve tool-specific syntax while aligning the behavioral
rules across Codex and Claude.

## Key Behaviors And Flows

1. The lead identifies covered edit tasks and their dependencies.
2. When delegation is available, the lead assigns each edit to a narrowly scoped worker with explicit ownership and expected output.
3. The lead launches independent, disjoint tasks concurrently and sequences dependent or overlapping tasks.
4. Workers implement and return concise results; the lead integrates their outputs and performs deterministic verification.
5. Any required correction is sent to a follow-up worker.
6. If delegation is unavailable or prohibited, the lead may edit locally and explicitly reports the fallback reason.

## Data, Permissions, And Constraints

- Workers share the repository, so concurrent ownership must be disjoint.
- Existing single-writer phase authority remains intact: the writer lane owns the phase and orchestrates its workers rather than introducing a competing peer writer.
- Delegation must respect active host policy and available tools.
- State and findings continue to be written only through their mandated helpers.
- Generated handoff packages remain owned exclusively by `handoff-package`.

## Error Handling And Edge Cases

- No subagent support: use the local fallback and report why.
- Host prohibits delegation: use the local fallback and cite the host restriction.
- Overlapping file ownership: serialize the tasks or give the full overlapping scope to one worker.
- Worker returns incomplete or failing work: dispatch a correction with the exact verification failure.
- Trivial edit: still delegate when workers are available; there is no size-based exception.
- Integration reveals a one-line fix: dispatch it rather than letting the lead patch it directly.

## High-Level Implementation Success

- User/stakeholder success: agents visibly behave as orchestrators throughout code and documentation delivery.
- Product constraints: preserve the existing chain stages, gates, artifacts, and provider parity.
- Operational constraints: do not weaken deterministic verification, file-ownership safety, or fallback completion.
- Existing behavior to preserve: the lead remains accountable for the final integrated result and all release gates.
- Downstream attention needed: requirements must distinguish covered edits from lead-owned operational and planning artifacts.

## Downstream Handoff Notes

- For visual-companion: not applicable; this feature has no product UI.
- Mockup-relevant product inputs: none.
- For requirements-engineer: specify the delegation contract, covered skills, orchestration responsibilities, concurrency rules, and fallback reporting.
- For architecture/planning: prefer direct skill-local wording; do not introduce a shared framework or automated enforcement.

## Explored Alternatives

### Shared Orchestration Contract

- Summary: define the policy once and make covered skills reference it.
- Why not selected: adds a dependency that installed skills must locate and maintain.

### Global AGENTS.md Rule

- Summary: express the policy only as a repository-wide agent instruction.
- Why not selected: it would not reliably travel with installed skills and would mix framework behavior with repository-owned durable context.

## Assumptions Confirmed

- Mandatory means no direct lead edits of covered artifacts when delegation is available.
- Local fallback is acceptable only when delegation is unavailable or prohibited.
- Planning and operational artifacts remain lead-owned.
- The policy applies to interactive and unattended runs.
- Instruction updates are sufficient for this PROJ; automated enforcement is deferred.

## Risks And Trade-Offs

- Mandatory delegation adds latency even for trivial edits; this cost is accepted.
- Parallel workers may collide; concurrency is limited to disjoint ownership.
- Follow-up worker dispatch is slower than a direct integration patch; preserving orchestration separation takes priority.
- Host capabilities differ; local fallback keeps workflows usable but must be visible.
- Provider instructions need some syntactic divergence even though their behavior remains aligned.

## Testing Focus

- Confirm every covered skill states mandatory delegation, lead responsibilities, concurrency safety, and explicit fallback behavior.
- Confirm excluded skills and artifact classes remain lead-owned.
- Confirm Codex and Claude copies express equivalent behavior without assuming the other provider's tools.
- Run the repository's existing validation suite before publishing changes.

## Next Step

- Backend/workflow feature: `requirements-engineer`.
