---
name: cross-review
description: "Route review of an artifact to the provider OPPOSITE its author (Claude-authored → codex exec, Codex-authored → claude -p) so review never happens in the authoring model's echo chamber. Use when: (1) P7 curated docs need the truth-check before the phase seals (the one active call site), (2) a degraded single-provider run needs a model-opposite review. Not for: finding bugs in code (use qa), form/size caps (curation-caps.sh in documentation), P3 pre-mortem or P4 plan review (Stage 3 — not wired yet)."
---

# Cross-Review — The Opposite-Provider Gate

Owns the cross-model review mechanism of the agent workflow (CONCEPT.md
§4). Same-model review is an echo chamber: persona prompts vary the
PROMPT but not the model's blind spots. This skill routes review to the
provider opposite the artifact's author — headless, strictly read-only,
bounded — and lands findings in the ledger like every other source.

**The invariant this skill exists to enforce: a review gate is NEVER
satisfied by the same model that authored the artifact.**

## Call sites

| Call site | Artifacts | Status |
|---|---|---|
| **P7 docs review** | curated docs delta (+ full capped docs) vs the PROJ diff | **ACTIVE** — invoked by **documentation** (7) before P7 seals; Critical/High BLOCK the phase |
| P3 pre-mortem | architecture-delta + PRDs | Stage 3 — do NOT improvise |
| P4 plan review | wave plans + gate config + api-contracts | Stage 3 — do NOT improvise |

The mechanism (scripts below) is call-site-agnostic; only `docs` mode is
accepted until the Stage 3 call sites ship.

## Mechanics

Everything deterministic is in `scripts/` — the skill (or the P7 writer
lane) runs one command:

```bash
bash scripts/cross-review.sh docs <X> <theme> \
  --artifacts docs/ARCHITECTURE.md docs/PRODUCT.md docs/GUIDELINES.md \
  --author-key docs-delta \
  --diff-base "$(bash scripts/state.sh get <X> <theme> .base_sha)" \
  --round 1
```

What it does, in order:

1. Resolves `author_provider` + `author_model` from
   `.authorship["<key>"]` in state.json (fallback: the phase's last
   writer lane). No resolvable author → hard error, the gate cannot run.
2. Renders `templates/cross-review-prompt.md.tmpl` (mode + artifact list
   + author provider + diff scope) — one provider-neutral adversarial
   prompt for either CLI.
3. Routes: opposite provider available → its adapter
   (`review-with-codex.sh` = `codex exec --sandbox read-only`,
   `review-with-claude.sh` = `claude -p --allowedTools Read,Grep,Glob`).
   Opposite provider missing/unauthenticated → **MODEL-opposite**
   fallback via `review-with-claude.sh --model $CLAUDE_REVIEW_MODEL`,
   refused if that equals `author_model`. Every degraded round is
   recorded (`degraded_fallback: true`) and later rendered into the
   morning report and PR body — never silent.
4. `--joint`: jointly curated artifacts get independent Claude AND Codex
   passes, launched concurrently; dedupe happens in the ledger AFTER
   provider attribution is stamped on every line.
5. Normalizes adapter output to findings JSON lines
   (`source: cross-review`, `provider` set) and pipes them into
   `node scripts/ledger.mjs add` — the ledger stays the sole write path.
   The `review-clean` marker line proves the adapter ran; it is not
   ingested.
6. Appends a round record to `.cross_review` in state.json (via
   state.sh) and exits: `0` clean · `3` Critical/High ingested ·
   `1` infrastructure failure.

## Severity rules (no new ones)

- **Critical/High** → BLOCK the calling phase. Fix, then ONE re-review
  round (`--round 2`). Still red → stop policy §8: park the run, the
  human decides in the morning. `--round 3` is refused by the script.
- **Medium/Low** → auto-defer as debt (§8), never block.

## Boundaries

- Adapters are strictly read-only; timeouts kill the whole process
  group (TERM then KILL) — no orphaned CLI trees.
- This skill checks TRUTH. Form (size caps) is `curation-caps.sh` in
  the documentation skill — run that FIRST, caps-breach output would
  only pollute this review.
- Never bypass the gate by setting `CLAUDE_REVIEW_MODEL` to the writer
  model — cross-review.sh refuses same-model reviews, and run-phase.sh
  refuses to start with equal writer/review models.
