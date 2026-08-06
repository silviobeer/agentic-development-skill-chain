---
name: cross-review
description: "Route a concept, architecture, implementation plan, or curated documentation to the provider opposite its author for an adversarial, read-only review. Use after creating a concept (1_brainstorming), architecture (3), wave plans (4_writing-plans), or P7 curated docs when the user elects a cross-model review. Works before P0 without state.json. Not for code-bug testing (use qa) or form/size caps (use curation-caps.sh)."
---

# Cross-Review — Opposite-Provider Gate

Same-model review is an echo chamber. This skill asks the other provider to
try to break an artifact, with identical severity rules and JSON Lines output
for every mode. It never starts by itself: the producing skill asks the human
at handoff, defaulting to yes.

## Modes

| Mode | Artifact | Review focus |
|---|---|---|
| `concept` | `1_brainstorm/PROJ-<X>-concept.md` | product coherence, buildability, boundaries, grounding |
| `architecture` | `3-4_plan/PROJ-<X>-architecture.md` | decisions, feasibility, traceability, risk |
| `plan` | wave plans and gate config | executability, coverage, sequencing, scope |
| `docs` | curated documentation | factual truth, staleness, cap-gaming, durable-rule quality |

Supply source artifacts that establish truth through `--ground-truth`; the
script embeds both artifacts and ground truth with `cat -n` line numbers. A
`--diff-base` embeds that git diff. The reviewer has no need or permission to
run commands, making read-only behaviour independent of sandbox support.

## Run it

Before P0, state.json does not exist. Pass the author explicitly; findings are
written to stdout for the human, never to a ledger:

```bash
bash scripts/cross-review.sh concept <X> <theme> \
  --artifacts specs/PROJ-<X>-<theme>/1_brainstorm/PROJ-<X>-concept.md \
  --ground-truth specs/PROJ-<X>-<theme>/0_context/existing-state.md \
  --author-provider claude --author-model <writer-model> --round 1
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

```bash
bash scripts/cross-review.sh docs <X> <theme> \
  --artifacts docs/ARCHITECTURE.md docs/PRODUCT.md docs/GUIDELINES.md \
  --author-key docs-delta \
  --diff-base "$(bash scripts/state.sh get <X> <theme> .base_sha)" --round 1
```

Exit codes: `0` clean or non-blocking only; `3` Critical/High findings;
`1` infrastructure failure; `64` invalid use. Critical/High findings block the
current handoff: fix and perform one re-review (`--round 2`); a remaining red
round goes to the human. Medium/Low findings are reported or deferred as debt.

## Routing and output integrity

- Claude-authored artifacts go to Codex; Codex-authored artifacts go to Claude.
  `--joint` runs both independently. If Codex is unavailable, a different
  Claude model may be used only when it is not the author model; that is marked
  as a degraded persistent review.
- Adapters reject zero findings, `review-blocked`, recognizable Bubblewrap or
  user-namespace failures, and any output that mixes `review-clean` with a
  finding.
- Findings are deduplicated by `category + file + line + summary` before they
  reach stdout or the ledger. `review-clean` is a liveness marker, never a
  finding.
- The default 128 KiB embedded-context limit fails explicitly if exceeded.
  Narrow the review inputs, or deliberately set
  `CROSS_REVIEW_MAX_CONTEXT_BYTES` for a reviewed larger prompt.
