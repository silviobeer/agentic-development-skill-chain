# PROJ-2 Concept - Wave-Scoped Ralph

## Status

Approved concept

## Feature Seed

Reduce Step 5 execution time by removing redundant, tightly nested Ralph
verification while preserving deterministic proof and comprehensive QA.

## Decomposition Context

- Original broader seed: make implementation orchestration faster and more effective.
- Approved project map: PROJ-1 owns subagent-first orchestration; PROJ-2 independently optimizes Step 5 verification semantics.
- This PROJ's role: replace per-story Outer Ralph with wave-scoped verification and remove duplicate QA work.
- Sibling PROJs: `PROJ-1-subagent-first-orchestration`.
- Depends on: none; the policies are complementary and may be implemented independently.
- Blocks: none.
- Scope intentionally assigned to another PROJ: worker ownership and mandatory delegation remain in PROJ-1.

## Project Context

- Existing system: Step 5 runs worker TDD and Inner Ralph, a mandatory per-story Outer Ralph loop, a wave gate, a PROJ quality gate, first-pass QA, and then mandatory Step 6 comprehensive QA.
- Relevant constraints: preserve deterministic acceptance evidence, regression gates, provider parity, bounded recovery, and the existing state/findings helper rules.
- Prior related specs: PROJ-1 defines which agent owns edits; this PROJ defines when verification and repair occur.

## Problem And Goal

The current execution workflow repeats checks at several nested levels and
interrupts a wave after every completed story. Passing acceptance criteria may
be executed repeatedly even when relevant code has not changed, while Step 5
and Step 6 both run QA. This increases model, tool, and wall-clock time without
proportionate assurance.

The goal is a faster green path: verify and repair at wave scope, reuse proof
only when it is bound to the current committed code, and retain deep recovery
for genuine failures.

## Primary Users And Scenarios

- An interactive lead executes a wave containing one or more independent stories without pausing for a separate Outer Ralph loop after each story.
- An unattended P5 writer completes all wave workers, coordinates one wave-level verification pass, and proceeds automatically when evidence is green.
- A wave with several failing ACs dispatches disjoint repairs concurrently rather than serially repeating every passing check.
- A stubborn failure escalates through fresh diagnosis and a different implementation attempt before the run blocks.

## Current Workflow Or Pain

- Inner Ralph already asks the implementer to check specification, quality, and tests.
- Outer Ralph then reruns every AC after each story and may rerun all ACs after each fix.
- The wave gate verifies AC commands and regressions again.
- The PROJ quality gate adds another verification layer.
- Step 5 performs first-pass QA immediately before mandatory comprehensive Step 6 QA.
- These nested loops serialize otherwise independent wave work and repeat green checks.

## Success Criteria

- Green-path stories do not trigger separate per-story Outer Ralph loops.
- Inner Ralph is one bounded worker self-review covering spec compliance, code quality, and targeted tests.
- All wave ACs are checked together after wave workers complete, with safe checks run concurrently.
- Passing ACs are not rerun during repair unless the changed files can affect them.
- Same-HEAD evidence may satisfy the wave gate; changed relevant code invalidates affected evidence.
- Failure recovery follows two normal fix rounds, one fresh diagnostic round, and one diagnosis-driven implementation round.
- `wave-gate.sh` remains the hard wave boundary and runs the declared regression suite.
- Step 5 first-pass QA is removed; Step 6 comprehensive QA remains mandatory.
- The PROJ quality gate focuses on assembled cross-wave risks instead of replaying wave ACs.
- Codex and Claude instructions remain behaviorally aligned.

## Scope

### In Scope

- Codex and Claude `executing` skills and their directly related execution references
- Inner Ralph semantics
- Wave-scoped Outer Ralph verification and repair
- AC evidence reuse and invalidation expectations
- Step 5 wave-gate handoff
- Step 5 PROJ quality-gate scope
- Removal of Step 5 first-pass QA and direct handoff to Step 6
- Human documentation describing Step 5

### Out Of Scope

- Subagent ownership and delegation policy, owned by PROJ-1
- Changes to PRD acceptance criteria or product behavior
- Removal of deterministic AC checks, regression suites, wave gates, or Step 6 QA
- Wall-clock benchmarking infrastructure or numeric performance targets
- Changes to other chain stages except their Step 5 handoff wording
- Unbounded retry loops or automatic acceptance of failing work

### Later

- Runtime metrics for verification duration and cache hit rates
- Automated selection of impacted ACs beyond existing plan metadata

## Selected Direction

Use a wave-scoped Outer Ralph pass after all wave workers finish. Batch
failures, parallelize disjoint repairs, rerun only failed or impacted checks,
and preserve `wave-gate.sh` as the final hard proof. Simplify Inner Ralph to one
self-review pass and remove Step 5's duplicate QA stage.

## Key Behaviors And Flows

1. Workers implement independent stories in the wave and each performs one bounded Inner Ralph self-review with targeted tests.
2. After all workers return, the lead runs every wave AC once, concurrently where commands are safe to parallelize.
3. The lead groups failures by disjoint ownership and dispatches the first normal fix round.
4. The lead reruns failed and plausibly impacted ACs, then uses fresh workers for a second normal fix round if needed.
5. Remaining failures go to a fresh diagnostic worker that may identify a root cause, invalid test, or misunderstood requirement.
6. A different implementation worker applies the diagnosis and the lead reruns impacted ACs.
7. If verification passes, the current-HEAD evidence is presented to `wave-gate.sh`; the gate validates evidence and runs regressions and its remaining checks.
8. If the four-stage recovery cannot produce passing ACs, the existing blocked-run evidence path remains the final safety boundary.
9. After all waves, the PROJ quality gate checks cross-wave integration, build, quality-phase commands, review findings, and applicable static analysis without replaying wave ACs.
10. Step 5 hands directly to Step 6 for comprehensive QA.

## Data, Permissions, And Constraints

- Cached AC evidence must remain bound to stable AC identity, command, selected tests, and committed HEAD.
- A code change invalidates every AC whose declared files or test selection may be affected.
- Concurrent commands and fix workers require disjoint resources and file ownership; shared databases, auth budgets, migrations, and servers retain existing serialization locks.
- Progress evidence must distinguish initial verification, repair rounds, diagnosis, recovery, cache reuse, and invalidation.
- State and findings remain writable only through `state.sh` and `ledger.mjs`.

## Error Handling And Edge Cases

- Single-story wave: still uses the same wave-scoped flow, without team overhead beyond the existing worker.
- Several ACs fail across disjoint stories: repair concurrently by ownership cluster.
- One fix can affect a previously passing AC: invalidate and rerun that AC before the gate.
- Diagnostic worker concludes the AC is invalid or contradictory: record the evidence and route the requirement conflict through the existing blocked/escalation path; do not silently weaken the AC.
- Failure remains after diagnosis-driven recovery: block with exact commands and attempt history rather than looping indefinitely or falsely passing.
- Wave gate finds a regression not covered by AC verification: dispatch the existing bounded gate fix flow and rerun the gate.
- Step 6 finds a bug previously caught by Step 5 QA: P6 owns the fix/re-verification loop, preserving coverage without duplicate discovery work.

## High-Level Implementation Success

- User/stakeholder success: ordinary green waves complete with fewer serialized verification stages and no duplicate QA phase.
- Product constraints: hard gates, deterministic evidence, regression coverage, and comprehensive QA remain intact.
- Operational constraints: recovery stays bounded and shared external resources remain serialized.
- Existing behavior to preserve: incomplete or contradictory work cannot pass a wave gate.
- Downstream attention needed: requirements and planning must define evidence invalidation and recovery transitions precisely.

## Downstream Handoff Notes

- For visual-companion: not applicable; this feature has no product UI.
- Mockup-relevant product inputs: none.
- For requirements-engineer: specify the green path, four-stage recovery, impacted-AC rules, evidence binding, QA handoff, and provider parity.
- For architecture/planning: reuse existing wave plan metadata and gate mechanisms; avoid new benchmarking or orchestration frameworks.

## Explored Alternatives

### Keep Per-Story Outer Ralph With A Smaller Cap

- Summary: retain the current position but reduce three iterations to one or two.
- Why not selected: it preserves serialization and repeated setup after every story.

### Remove Outer Ralph Entirely

- Summary: rely on worker tests and run `wave-gate.sh` directly.
- Why not selected: failures would force repeated execution of expensive gate stages and remove the useful pre-gate independent check.

### Require A Numeric Runtime Reduction

- Summary: benchmark Step 5 and enforce a percentage improvement.
- Why not selected: runtime varies heavily with project scope, provider latency, external services, and quality tools; the approved goal is structural.

## Assumptions Confirmed

- PROJ-2 is separate from the approved PROJ-1 orchestration policy.
- Inner Ralph becomes one bounded worker self-review.
- Outer Ralph moves to wave scope.
- Only failed or plausibly impacted ACs repeat during repair.
- Recovery uses two fix rounds, fresh diagnosis, and diagnosis-driven implementation.
- Step 5 first-pass QA is removed while Step 6 remains mandatory.
- Success is structural rather than benchmark-based.

## Risks And Trade-Offs

- A foundational problem may be discovered later in a wave; independent wave planning and worker targeted tests reduce this risk.
- Impact selection may miss a regression; the final wave gate still validates evidence and runs the declared regression suite.
- Moving all comprehensive QA to Step 6 delays some bug discovery but eliminates duplicate work and retains the P6 fix controller.
- Difficult failures may still take four recovery stages; the common green path is optimized while the exceptional path remains rigorous.
- Cached proof can become stale; binding and invalidation rules prevent reuse across relevant changes.

## Testing Focus

- Confirm the execution instructions contain no mandatory per-story Outer Ralph loop.
- Confirm wave-level AC verification batches independent checks and repairs safely.
- Confirm relevant changes invalidate cached AC evidence before the wave gate.
- Confirm the four-stage recovery is bounded and cannot silently pass failures.
- Confirm Step 5 no longer performs first-pass QA and still hands off to mandatory Step 6.
- Confirm the PROJ quality gate does not replay wave ACs.
- Confirm Codex and Claude behavior remains aligned.
- Run `./scripts/validate.sh` before publishing changes.

## Next Step

- Backend/workflow feature: `requirements-engineer`.
