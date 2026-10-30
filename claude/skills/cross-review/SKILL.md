---
name: cross-review
description: "Route a concept, PRD set, architecture, implementation plan, QA evidence, or curated documentation to the provider opposite its author for an adversarial, read-only review. Used by requirements-engineer before PRD handoff, inside QA for its required evidence review, and after creating a concept, architecture, wave plans, or P7 curated docs. Works before P0 without state.json. Not a replacement for runtime QA or form/size caps."
---

# Cross-Review — Opposite-Provider Gate

## External handoff ground truth (conditional)

When reviewing a PROJ with `external-handoff.json`, read [the receiving input contract](../2e_handoff-refinement/references/input-contract.md). Supply the marker, complete scoped immutable baseline, explicit responses, engineering requirements and repository/dependency mapping through `--ground-truth`; local `2_PRDs/` globs below apply only to linear projects. Missing referenced external inputs fail validation and must not be omitted. Verify hashes and identify baseline version/revision in the review result.

Classify product questions separately from engineering defects and missing evidence. A clean model review cannot approve a product change or clear its question. Inspect proposed refinement with `requirements` mode against the product baseline, without requiring that the received package adopt the local PRD layout. Keep all reviewed source artifacts read-only and preserve verbatim source language. Product questions go in the portable feedback exchange; existing stage ledgers continue to hold review defects through their helpers. The review result belongs to the refinement run whose inputs it reviewed (`runs/<run-id>/refinement/reviews/`); it does not carry over to a new run or a changed inventory.

Same-model review is an echo chamber. This skill asks the other provider to
try to break an artifact, with identical severity rules and normalized JSON
Lines output for every mode. It never starts by itself: the producing skill
invokes it automatically when its outputs are saved, before user approval or
handoff. Concept, architecture, plan, requirements, QA, and P7 documentation
reviews are mandatory gates; do not ask the user whether to start them.

## Artifact Language

In requirements, architecture, plan, QA and documentation mode, write finding
summaries and review records in English, even for non-English source material.
Flag newly authored non-English prose in artifacts from Step 2 onward; preserve
paths, identifiers, quoted evidence and intended product localization. Concept
reviews keep the concept's chosen language. Preserve already CP1-sealed
PRD/plan ACs verbatim on resume; a later language-policy update alone must not
reopen approval. New records remain English; changing sealed canonical ACs
requires explicit user authorization and the owning review. User-facing
explanations may use the user's language.

## Modes

| Mode | Artifact | Review focus |
|---|---|---|
| `concept` | `1_concept/PROJ-<X>-concept.md` | product coherence, buildability, boundaries, grounding |
| `requirements` | the complete `2_PRDs/PROJ-<X>-PRD-*.md` set | concept and UI traceability, story/AC testability, edge behavior, cross-PRD consistency, architecture leakage |
| `architecture` | `3-4_plan/PROJ-<X>-architecture.md` | decisions, feasibility, traceability, risk, Summary fidelity |
| `plan` | wave plans and gate config | executability, coverage, sequencing, scope |
| `qa` | QA summary/evidence plus implementation diff | evidence integrity, adversarial coverage, finding quality, release decision; `--personas` runs six isolated discipline reviewers (or the subset named by `--personas <list>`) |
| `docs` | curated documentation | factual truth, staleness, cap-gaming, durable-rule quality, every new Trap against [the trap test](../../../CONCEPT.md#trap-test-and-rule-placement) |

Supply source artifacts that establish truth through `--ground-truth`; the
script embeds both artifacts and ground truth with `cat -n` line numbers. A
`--diff-base` embeds that git diff. Add `--diff-paths` with normal Git
pathspecs for large PROJs; the prompt names every changed path omitted by that
scope. Embedded material defaults to a 900,000-byte ceiling and fails before
the provider call rather than truncating. The reviewer has no need or
permission to run commands, making read-only behaviour independent of sandbox
support.

## Run it

If `scripts/chain review` has not been installed in the project yet, use
`~/.claude/skills/5_executing/scripts/chain review` in the commands below.
Run from the project root so artifact paths resolve correctly.

Before P0, pass the author explicitly. In an existing PROJ directory, findings
are saved through `chain findings add --stage <mode>` even without state.json.
Outside a PROJ structure (no `specs/PROJ-<X>-<theme>/`), report findings only;
never create a project directory, ledger or runtime state for a free-standing review.
A clean review creates no findings file.

Storage inside a PROJ:

| Review | Ledger |
|---|---|
| Concept | `1_concept/findings.json` |
| Requirements | `2_PRDs/findings.json` (linear); `refinement/findings.json` (external handoff) |
| Architecture and plans | `3-4_plan/findings.json` |
| Implementation, CodeRabbit, Sonar and debt | `5_progress/findings.json` |
| QA | `6_qa/findings.json` |
| Documentation | `7_documentation/findings.json` |
| Delivery | `8_delivery/findings.json` |

For projects with `external-handoff.json`, requirements-mode findings belong in
project-level `refinement/findings.json`, shared across runs. Before reviewing an
existing external project, run `chain findings migrate-refinement <X> <theme>`.
It moves an existing `2_PRDs/findings.json` (or legacy `3_PRDs/findings.json`)
byte-for-byte under the project lock; rerunning is safe. Other files remain in
place. If old and new ledgers both exist (all reads then fail closed), the same
command merges them into `refinement/findings.json`, keeping every record verbatim;
a finding ID whose records differ stops the merge for its owner to resolve. Until
migration, helpers retain the old ledger as its owner. Never rename/delete it
manually or create a per-run ledger.

`chain findings list` aggregates these files and an existing legacy root ledger
without writing a central copy. IDs remain unique per PROJ; status and attempt
updates find the owning file automatically. Use `list --stage <mode>` for one
stage. Review the aggregated ledger when reconciling open findings. Retain fixed
and deferred records in their original folder. Existing legacy folders remain
in use; no automatic move of existing ledgers.

Example:

```bash
bash scripts/chain review concept <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md \
  --ground-truth specs/PROJ-<X>-<theme>/0_context/existing-state.md \
  --author-provider claude --author-model <writer-model> --round 1
```

For requirements, review the complete PRD set against the concept and the
compact UI contracts that exist. Prefer `implementation-handoff.md`, sitemap,
layout decision, and design language over embedding every mockup HTML file:

```bash
bash scripts/chain review requirements <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-*.md \
  --ground-truth specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md \
    specs/PROJ-<X>-<theme>/1d_prototypes/implementation-handoff.md \
  --author-provider <current-writer> --round 1
```

Use `architecture` with the concept, every PRD in `2_PRDs/`, and the curated
`docs/ARCHITECTURE.md` and `docs/GUIDELINES.md` as ground truth; `plan` takes
the architecture and the same PRDs. Feasibility and traceability are only
checked against what is supplied, so a PRD left out is a requirement nobody
reviews. If a referenced input does not exist, omit it; do not invent a
replacement.

`--also-focus <concept|requirements|architecture|plan,...>` appends the review
focus of further artifact kinds to the primary mode's, so one run reviews a
combined set (used by `fast-track-spec`: `architecture --also-focus
concept,requirements`). The mode stays the primary one: it picks the ledger
folder and the `.cross_review[]` record that CP1's fast path reads. Not valid
for `qa` or `docs`.

`--personas [chen,weber,...]` (QA only, never with `--joint`) takes an optional
comma list of the six personas, by last or first name, case-insensitive: `chen`,
`weber`, `sharma`, `mueller`, `rodriguez`, `takahashi`. No list runs all six, as
before. A subset runs in canonical order (the first chosen persona is the
quota probe), keeps the batching by `resources.max_parallel_commands`, and adds a
`personas` array to the `.cross_review[]` record (absent = all six). An unknown or
empty name exits 64 before any worker starts. `6_qa` § QA Profile chooses the
subset for fast-track PROJs.

After P0, omit `--author-provider` and use `--author-key` to resolve authorship
from state.json. That is the persistent gate path: findings are added only via
`chain findings`, and the round is appended only via `chain state`.

When the caller knows the author but must persist the review, pass both
`--author-provider <claude|codex>` and `--persist`. `--require-provider codex`
or `claude` makes an unavailable/opposite fallback fail rather than silently
replacing the required reviewer. For Claude-authored QA, use `qa --personas`:
it launches six separate Codex reviews (the first alone as a quota probe, the other five in parallel batches of `resources.max_parallel_commands`, default 2). If Codex is unavailable,
the script prints a degraded-mode warning, records `degraded_fallback: true`,
and runs the same six personas on the strongest Claude model, even when that is
the author model (`CLAUDE_MODEL_RANK`, default `fable opus sonnet`; override with
`CLAUDE_REVIEW_MODEL`); the QA caller must tell the user
that independent-provider review was unavailable. Codex-authored QA launches
six separate Claude reviews; when Claude is missing, unauthenticated or runtime quota-exhausted it runs six
separate Codex reviews instead, flagged degraded. Other Codex-authored modes
still fail closed without Claude. Keep `--require-provider`
for handoffs where a fallback must instead stop the gate.

Authentication is not an inference-capacity probe. Adapters return exit 75 for
recognized failed quota/rate-limit/capacity responses; other failures stay closed.
Every failed adapter emits a sanitized `cross-review-failed-attempt` JSON record
on stderr (mode, round, actual provider/model, classification, exit code and time).
Retain the command log. Failed attempts never append a completed review round.
Unpinned `qa --personas` may restart all six personas once on the other available
provider, recording genuine reviewer attribution and `degraded_fallback: true`;
discard the partial failed panel. Stop at the first failed worker, with no
same-provider retries or retry fan-out. Required-provider pins and non-QA modes,
including documentation truth gates, fail closed on runtime unavailability.
The existing pre-launch model-opposite fallback for Claude-authored non-QA
reviews remains explicit and must differ from the author model.

```bash
bash scripts/chain review docs <X> <theme> \
  --artifacts docs/ARCHITECTURE.md docs/PRODUCT.md docs/GUIDELINES.md \
  --author-key docs-delta \
  --diff-base "$(bash scripts/chain state get <X> <theme> .base_sha)" \
  --diff-paths . ':(exclude)specs/**' ':(exclude)**/*.test.*' \
    ':(exclude)**/*.spec.*' ':(exclude)tests/**' ':(exclude)e2e/**' \
  --round 1
```

Exit codes: `0` clean or non-blocking only; `3` Critical/High findings;
`1` infrastructure failure; `64` invalid use. Critical/High findings block the
current handoff.

The producing skill automatically reconciles findings and re-reviews with
`--round 2`, then `--round 3` while findings remain, including Medium/Low.
No confirmation is needed for another round or fixes within approved scope;
ask only when resolving a finding requires a product decision. Stop early
when there are no findings. Exit `0` alone does not mean zero findings: inspect
the emitted findings or the persisted round's `findings_added` count.
Each script invocation runs one read-only review; the producing skill applies
fixes between calls (QA delegates fixes to its P6 controller). On persistent
runs, update finding status through `chain findings` before re-review.
Three rounds is the automatic maximum: remaining Critical/High findings block handoff
and go to the human; remaining Medium/Low findings are reported or deferred
as debt. Additional manually requested rounds have no limit: continue with
`--round 4`, `--round 5`, and so on, preserving the same finding and handoff
gates. A manual request authorizes the requested rounds, not an unbounded
automatic loop. Infrastructure failures are not completed review rounds.

**Applying a finding: reconcile, don't narrate.** Rewrite the affected section of
the artifact as if it were correct the first time. Never leave "Correction
(post-review)," "Post-cross-review addition," "an earlier draft said X," or similar
narrated-diff scaffolding in the artifact itself — that turns every future reader
into an archaeologist who has to reconstruct current truth from a change log. The
round's findings and the fix are already recorded in the cross-review output
consumed at handoff time; the artifact only needs to be correct, not annotated with
its own history.

## Routing and output integrity

- Claude-authored artifacts go to Codex; Codex-authored artifacts go to Claude.
  `--joint` runs both independently. If Codex is unavailable, the strongest
  Claude model that is not the author model is chosen automatically (QA personas
  take the strongest model even when it is the author model; rank
  `fable opus sonnet`, alias or full id compared by substring); that is marked
  as a degraded persistent review. Any route that selects Claude verifies CLI
  availability and authentication before launching the review.
- `qa --personas` starts six independent workers (security, principal
  engineering, performance, reliability, architecture, and minimalism), rather
  than asking one reviewer to impersonate a panel. The Claude-authored route
  prefers Codex and falls back loudly to six Claude workers only when Codex is
  unavailable.
- The Claude adapter requests validated `--output-format json` plus a JSON
  Schema, then normalizes `structured_output.findings` to the shared JSON Lines
  contract. Both adapters reject zero findings, `review-blocked`, recognizable
  Bubblewrap or user-namespace failures, and any output that mixes
  `review-clean` with a finding.
- Findings are deduplicated by `category + file + line + summary` before they
  reach stdout or the ledger. `review-clean` is a liveness marker, never a
  finding.
- Review prompts stream to both provider CLIs with a default 900,000-byte
  embedded-material ceiling. Set `CROSS_REVIEW_MAX_CONTEXT_BYTES` when the
  selected provider has a different verified limit (`0` means consciously
  unlimited). `--diff-paths` scopes large diffs and always tells both operator
  and reviewer which changed paths were omitted.
  Claude Code itself imposes a 10 MB stdin transport ceiling; the Claude
  adapter detects it before launch and fails with the exact cause rather than
  truncating or silently narrowing review scope.

For QA, `--diff-base` also embeds a current status-plus-diff snapshot with its
exact command/pathspecs, matched tracked-path count and HEAD. Distinguish a
clean change stream from zero selected paths; endpoint matching proves only
no net selected status/diff change. It does not certify unrecorded earlier endpoints,
transient reverted writes, untracked-file content changes, ignored/excluded paths or HEAD movement.
