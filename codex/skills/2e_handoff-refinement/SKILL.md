---
name: handoff-refinement
description: "Receive a versioned product handoff, inspect affected code repositories, separate engineering requirements from product questions, and prepare pinned repository inputs for architecture and execution. Also locates or records the team coordination location and repository inventory. Use for developer-side refinement of an external package, not product PRD authoring."
---

# Handoff Refinement

Refine a product-owned handoff into evidence-backed engineering inputs without taking ownership of its product requirements. This optional receiving workflow precedes architecture; the linear chain needs no additional files or approvals.

Show progress: run `bash ~/.claude/skills/5_executing/scripts/chain status --short <X>` (Codex: `~/.codex/skills/5_executing/scripts/chain`; `<X>` is this refinement project's PROJ number, or `new` while none exists yet) when this skill starts and again just before its closing prompt, and show its line unchanged; if it prints nothing or fails, continue without it.

## References

- [input-contract.md](references/input-contract.md) — the `external-handoff.json` schema, authority rules and resolver checks. During refinement you need § Storage and ownership and § Inventory; the remaining sections are for downstream consumers.
- [run-layout.md](references/run-layout.md) — where everything is stored, provenance words, status words, review-round record.
- [feedback-and-readiness.md](references/feedback-and-readiness.md) — product return package and readiness report.
- [evidence-brief.md](references/evidence-brief.md) — delegated read-only inspection and consistency briefs.
- [package-tools.md](references/package-tools.md) — byte copies, hashes, AC ranges, detached link checks, source status.
- [workspace-contract.md](references/workspace-contract.md) — inventory schema, access probe, clone/creation and baseline evidence; read before any clone or creation, when no valid marker exists, or when a repository's baseline is routed.

Product owns the immutable baseline and explicit product responses; engineering owns evidence, technical constraints and implementation decisions (authority rules: input contract § Storage and ownership). There is no blanket engineering-over-product precedence. Write new artifacts in English; never translate or rewrite a received requirement to satisfy a local validator.

## Coordination location

Handoffs, refinement and open decisions live in one agreed coordination location, marked by `delivery-workspace.json`: a dedicated repository, the handoff's source repository or an implementation repository. Find it with `scripts/workspace.mjs discover`: explicit team remote, current checkout, the handoff's source repository, user-supplied paths; otherwise ask, or search only the selected organization with authenticated tools. Directory names are not ownership evidence. Reuse a valid registered marker and its machine-local bindings; never initialize another coordination repo per package. An inaccessible remote is an access blocker, an unmarked repository is unregistered; neither permits replacement.

Without a marker, the team chooses the location and roles (workspace contract). Draft the inventory outside the coordination location, `check`, then `verify`, and register it through the team's branch/PR path; report draft, registered and team-accepted separately. Any clone or creation, including a valid marker's missing coordination checkout, follows the contract's setup procedure, starting with the `workspace.mjs access` probe; creation needs exact-target authorization and only serves a new dedicated remote. Never request credentials in chat. Keep machine-local bindings unversioned; create no placeholder trees, parent Git repos, nested repos or unrelated clones. No force-push, last-write-wins or new approval system.

## Receive and inspect

1. **Preflight.** Establish the source package, receiving location and intended deliverable (for example lab prototype versus production). If any is unresolved, ask one compact question naming all three; a corrected path or the current directory does not decide scope; reuse answers already given. Identify package version, product owner, affected repo keys and coordination location. Pin consumed shared inputs to a commit or content hash. A local commit is not team acceptance.
2. **Run.** Resume or create a run per the run layout. Copy the received package byte-identically with package-tools; never write into a generated `2b_handoff/` run. Write the run README's provenance table before any other result.
3. **Prototype.** Compare the package's prototype inclusion decision with the received files and record the actual `prototype` kind; preserve that decision rather than re-asking. A promised prototype that is missing, inaccessible or lacks start instructions is a package discrepancy for product feedback, not silently fulfilled by static references. Older packages without a decision record it as unspecified. Report prototype evidence as three separate statements: source present, version matches the handoff, executability actually checked in this session; screenshots are not a runnable prototype. Prototypes inform interaction only: a simulated prototype neither establishes production architecture nor narrows the baseline; derive scope from the ACs.
4. **Engineering direction checkpoint.** Before deep design, state the proposed direction, its engineering authority and any superseded proposal, so the developer can cheaply correct reuse-versus-replacement or runtime choices. Existing code is behavior evidence, not authority over the intended technology. These are engineering constraints, never product feedback or approval. Inspect relevant code; with several or large repositories, delegate one evidence brief per repository and verify a cited location per result. Cite repo key, commit, path; distinguish implemented from proposed behavior. Record testable engineering requirements separately, linked to source ACs or explicit authority. Never weaken a product AC by relabeling it technical. Declare an engineering story only for an independently verifiable technical outcome; never manufacture a product PRD.
5. **Repo baselines.** First separate the inventory into repositories this handoff affects and coordination-only ones; deepen baseline evidence only for affected repositories. A prototype's source repository is a reference, not an implementation repository, unless agreed ownership assigns it. Read each affected repo's intake status and run the read-only `scripts/workspace.mjs baseline` report against the seal and examined revision; record ancestry, curated-file presence/equality and remote acceptance separately (`local-sealed` alone is insufficient). Missing documents or divergent unequal baselines get a `baseline` prerequisite and reconciliation, not an automatic fresh intake. Incomplete intake resumes with its owner; suspected drift needs an explicitly chosen audit; planned repos route to bootstrap. Investigation and product questions may proceed meanwhile; readiness stays per repository.

## Scope before binding mappings

Record three things separately in `runs/<run-id>/refinement/findings.md`: the complete source inventory (every AC with `sourceId` and verbatim range), the investigation assignment (which repo was inspected for which ACs), and binding implementation/verification ownership. Inspecting a repository does not make it the owner. When the source describes a prototype, a separate system or an out-of-scope repository, leave ownership open (`repositories: []`, no mappings) and let `chain check inputs --allow-blocked` report the honest blockers; never assign ACs to satisfy the validator. A whole-deliverable ownership question references every AC of it; narrower questions only the affected criteria. Production questions (hosting, operations, scale) block production scope, not a separately assessed prototype. Do not invent a local PROJ or initialize every investigated repository. Record every unestablished interpretation of the source as an assumption with its evidence.

## Local project state

For each selected implementation repository with a bound checkout, establish its local PROJ ID and create `specs/PROJ-<X>-<theme>/` with its refinement inputs. From that checkout root run `bash <installed-5_executing>/scripts/chain state init <X> <theme>` (`~/.claude/skills/5_executing` or `~/.codex/skills/5_executing`) before its refinement review. This replaces Concept's initialization on this route: new state is `CP1:pending`, existing state is kept. Never reset a resumed project or infer CP1 approval from product approval; only Step 5 approves CP1.

Execution state lives only in its implementation repository. If a checkout is unavailable, record initialization as a prerequisite in its onboarding prompt. Record review defects with the findings helper, using `--stage requirements`; with `external-handoff.json` present it creates project-level `refinement/findings.json`, including before state exists. Before reviewing a resumed project, run `chain findings migrate-refinement <X> <theme>` to move its old requirements ledger without changing history (see cross-review). Keep this single ledger across runs; do not remove old ledgers manually.

## Repeat rounds and package consistency

Before a baseline recommendation and again before closing a long review, compare packaged source pins with the current source revision (`package-tools.mjs source-status`); record compared revisions and changed paths, and treat missing source access as missing evidence. Live source is context only: retain every frozen AC until explicitly amended, request new packaging for relevant changes and add a `source-reconciliation` prerequisite for affected repositories.

On repeat rounds, compare current inputs with the previously consumed baseline and responses, citing revisions and affected requirement IDs. The delta directs attention but grants no review exemption. Assess current requirements first, without using prior findings as the outline; then give every earlier finding and question a disposition (open, resolved with evidence, superseded with replacement, reassess with reason) in the existing artifacts and statuses. No new findings does not mean old questions are answered.

Allocate question, finding and evidence IDs once per project across all runs: scan earlier runs and `product-feedback/` rounds for the highest number; never reuse an ID. Earlier unapproved drafts get a disposition (carried, superseded, withdrawn) but contribute no decisions. Skip re-asking only when an accepted decision still applies to the current baseline, citing the applicability check. A technical decision is not product approval, a documented design is not implementation evidence, and implementation evidence is not integration acceptance.

Check package-wide consistency of states, roles, terminology, shared rules and cross-PRD transitions, optionally as parallel consistency briefs. Apply a reusable diagnostic to all relevant requirements, keep one issue identity with all affected references, record a brief reason for material impacts found not applicable, and route cross-project impacts to their owners.

## Product feedback and responses

Classify each issue by the decision it needs: product decision, technical investigation, architecture decision or operations/release decision. Only product decisions go to Product; the rest are settled with the developer in this session and recorded as engineering constraints or engineering stories, never as product blockers. Parsing, APIs, queues, storage or the library behind a clear AC are engineering, but an AC that no acceptable coverage option (existing code, installed dependency, platform, new library or justified hand-built) meets unchanged is a product question; whether a role, notification or workflow exists at all is product. Write each product question with the smallest blocking scope it affects, in the format of [feedback-and-readiness](references/feedback-and-readiness.md), under `runs/<run-id>/refinement/product-feedback/<round>/`. Do not send or publish without explicit authorization.

Ingest only explicit product responses per the contract's `responses` field; silence, a clean review, an open PR or a developer's assumption closes nothing. A superseding package keeps the prior version and requires reconciling affected questions, requirements, architecture, plans and tests; old approvals do not transfer. Product-owned source changes run through `review-reconcile` in the source project; the receiver never edits the original PRDs.

## Review and readiness

Create `external-handoff.json` and mappings per the input contract and validate with the resolver; `--allow-blocked` is for investigation and feedback only, never for architecture or execution.

Before the independent review, self-check and record the result in the run README:

- Every `blockingRepositories` entry and `ownership unresolved` blocker has matching prose, and nothing is non-blocking in prose while blocking in the inventory.
- Every question and finding cites the precise affected `sourceId`s.
- Every ownership claim cites evidence or is explicitly open; every unestablished interpretation is marked as an assumption.
- The provenance table covers every path under the run using only the run layout's words.

Run [cross-review](../cross-review/SKILL.md) in `requirements` mode with this run's refinement artifacts and the complete scoped baseline, responses, engineering constraints and code evidence as ground truth; on repeat rounds also supply prior findings/questions and input-change evidence and ask for their complete reconciliation. Store output under `runs/<run-id>/refinement/reviews/` and keep the single review-round record per the run layout. The review cannot resolve or defer product questions.

Write `runs/<run-id>/refinement/readiness.md` per feedback-and-readiness. Every source requirement needs implementation and verification ownership across the affected repositories or is listed as open; no repo must implement the entire baseline. Prepare pinned bundles in `refinement/repo-handoffs/<repo-key>/` only for repositories with settled ownership and scope, never depending on another developer's absolute paths. Report status only with the run layout's status words; a local seal, published branch or unauthenticated 404 proves neither team acceptance nor absence of a PR, so record the probe made and the next step.

Each implementation repo has its own project ID, checkout, state, tests and PR; shared architecture records repository boundaries and versioned interfaces; shared decisions and integration evidence stay in the coordination location. One green repo or open PR is not feature acceptance.

## Session handoff

Finish checks and the independent review here. Close the run with at most five prioritized next decisions (owner, blocked step, recommendation) and one concrete follow-up assignment, in both the run and project README. Then stop at a copyable prompt for a new user-started session; never auto-invoke architecture, intake, bootstrap or another producing skill (`/compact` is not a new session). Name the next skill, bound checkout, local project identity, pinned input/response revision, inventory and readiness paths, scope and blockers. Machine-local paths belong only in the personal prompt; with no checkout, give its onboarding action. Emit a start prompt only for a session required now with a real checkout (intake, bootstrap, baseline resume); list unresolved bootstrap as a later task with its prerequisites. Blocked scope gets the product return package or a baseline-resume prompt, not architecture.
