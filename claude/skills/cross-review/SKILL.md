---
name: cross-review
description: "Route a concept, PRD set, architecture, implementation plan, QA evidence, or curated documentation to the provider opposite its author for an adversarial, read-only review. Used by requirements-engineer before PRD handoff, inside QA for its required evidence review, and after creating a concept, architecture, wave plans, or P7 curated docs. Works before P0 without state.json. Not a replacement for runtime QA or form/size caps."
---

# Cross-Review — Opposite-Provider Gate

Same-model review is an echo chamber. This skill asks the other provider to
try to break an artifact, with identical severity rules and normalized JSON
Lines output for every mode. It never starts by itself: the producing skill
invokes it at handoff. Requirements, QA, and P7 documentation are mandatory
gates; concept, architecture, and plan reviews may still be elected by the
user.

## Modes

| Mode | Artifact | Review focus |
|---|---|---|
| `concept` | `1_brainstorm/PROJ-<X>-concept.md` | product coherence, buildability, boundaries, grounding |
| `requirements` | the complete `2_PRDs/*.md` set | concept and UI traceability, story/AC testability, edge behavior, cross-PRD consistency, architecture leakage |
| `architecture` | `3-4_plan/PROJ-<X>-architecture.md` | decisions, feasibility, traceability, risk |
| `plan` | wave plans and gate config | executability, coverage, sequencing, scope |
| `qa` | QA summary/evidence plus implementation diff | evidence integrity, adversarial coverage, finding quality, release decision; `--personas` runs six isolated discipline reviewers |
| `docs` | curated documentation | factual truth, staleness, cap-gaming, durable-rule quality |

Supply source artifacts that establish truth through `--ground-truth`; the
script embeds both artifacts and ground truth with `cat -n` line numbers. A
`--diff-base` embeds that git diff. Add `--diff-paths` with normal Git
pathspecs for large PROJs; the prompt names every changed path omitted by that
scope. Embedded material defaults to a 900,000-byte ceiling and fails before
the provider call rather than truncating. The reviewer has no need or
permission to run commands, making read-only behaviour independent of sandbox
support.

## Run it

Before P0, state.json does not exist. Pass the author explicitly; findings are
written to stdout for the human, never to a ledger:

```bash
bash scripts/cross-review.sh concept <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md \
  --ground-truth specs/PROJ-<X>-<theme>/0_context/existing-state.md \
  --author-provider claude --author-model <writer-model> --round 1
```

For requirements, review the complete PRD set against the concept and the
compact UI contracts that exist. Prefer `implementation-handoff.md`, sitemap,
layout decision, and design language over embedding every mockup HTML file:

```bash
bash scripts/cross-review.sh requirements <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/2_PRDs/*.md \
  --ground-truth specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md \
    specs/PROJ-<X>-<theme>/1d_mockups/implementation-handoff.md \
  --author-provider <current-writer> --round 1
```

Use `architecture` with the concept, every PRD in `2_PRDs/`, and the curated
`docs/ARCHITECTURE.md` and `docs/GUIDELINES.md` as ground truth; `plan` takes
the architecture and the same PRDs. Feasibility and traceability are only
checked against what is supplied, so a PRD left out is a requirement nobody
reviews. If a referenced input does not exist, omit it; do not invent a
replacement.

After P0, omit `--author-provider` and use `--author-key` to resolve authorship
from state.json. That is the persistent gate path: findings are added only via
`ledger.mjs`, and the round is appended only via `state.sh`.

When the caller knows the author but must persist the review, pass both
`--author-provider <claude|codex>` and `--persist`. `--require-provider codex`
or `claude` makes an unavailable/opposite fallback fail rather than silently
replacing the required reviewer. For Claude-authored QA, use `qa --personas`:
it launches six separate Codex reviews in parallel. If Codex is unavailable,
the script prints a degraded-mode warning, records `degraded_fallback: true`,
and runs the same six personas with Claude; the QA caller must tell the user
that independent-provider review was unavailable. Codex-authored QA launches
six separate Claude reviews and fails closed when `claude auth status` is not
green; it never substitutes Codex for its own work. Keep `--require-provider`
for handoffs where a fallback must instead stop the gate.

```bash
bash scripts/cross-review.sh docs <X> <theme> \
  --artifacts docs/ARCHITECTURE.md docs/PRODUCT.md docs/GUIDELINES.md \
  --author-key docs-delta \
  --diff-base "$(bash scripts/state.sh get <X> <theme> .base_sha)" \
  --diff-paths . ':(exclude)specs/**' ':(exclude)**/*.test.*' \
    ':(exclude)**/*.spec.*' ':(exclude)tests/**' ':(exclude)e2e/**' \
  --round 1
```

Exit codes: `0` clean or non-blocking only; `3` Critical/High findings;
`1` infrastructure failure; `64` invalid use. Critical/High findings block the
current handoff: fix and perform one re-review (`--round 2`); a remaining red
round goes to the human. Medium/Low findings are reported or deferred as debt.

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
  `--joint` runs both independently. If Codex is unavailable, a different
  Claude model may be used only when it is not the author model; that is marked
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
