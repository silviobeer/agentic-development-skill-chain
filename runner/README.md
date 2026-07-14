# Runner — Host-Neutral Dual-Lane Phase Runner (Stage 1)

The thin runner from CONCEPT.md §5/§6b: it starts fresh Claude and
Codex lanes per phase, keeps exactly one writer per phase, and hands
state between phases ONLY via `specs/PROJ-<X>-<theme>/state.json` and
files on disk. No conversation history crosses a phase boundary.

## Contents

| File | Purpose |
|---|---|
| `run-phase.sh` | run one phase (`P0 P5 P6 P7 P8`) or `auto` (all remaining phases → morning report) |
| `render-report.mjs` | `morning` (scan all PROJs → `specs/morning-report-<date>.md` + one-liner) and `stop` (stop report) |
| `spike-dual-lane.sh` | Stage 1 release gate: concurrent lanes, read-only enforcement, JSONL capture, attribution, kill-tree cancellation |
| `prompts/lane-prompt.md.tmpl` | generic lane prompt (role rules, state discipline) |
| `prompts/p6-controller.md` | the P6 phase-controller contract (ledger triage, fix dispatch, opposite re-verification) |
| `templates/morning-report.md.tmpl`, `templates/stop-report.md.tmpl` | report frames — reports are rendered, never hand-written |
| `schemas/state.schema.json`, `schemas/findings.schema.json` | documented contracts for the two machine files (validation is embedded in `state.sh` / `ledger.mjs`) |

## Typical overnight run

```bash
# after CP1 was approved via the checkpoint skill (state.json = CP1:approved):
runner/run-phase.sh auto <proj-x> <theme>            # P0 → P5 → P6 → P7 → P8
# morning: read specs/morning-report-<date>.md, then review the PR (CP2)
```

Single phase / resume after a stop:

```bash
bash scripts/state.sh transition <proj-x> <theme> <phase> running   # resume from blocked
runner/run-phase.sh <phase> <proj-x> <theme> [--timeout 3600] [--writer claude|codex]
```

## Invariants the runner owns

- **Single writer:** one lane per phase may write; the peer lane runs
  with read-only tools (`--allowedTools Read,Grep,Glob` /
  `codex exec --sandbox read-only`). Peer findings are ingested into
  the ledger; a failed peer never stops the run.
- **Degraded mode is never silent:** codex missing or unauthenticated →
  single-provider run; the peer/review lane uses a different Claude
  model (`CLAUDE_REVIEW_MODEL`, default `sonnet`); `degraded` is set in
  state.json and rendered into the morning report and PR body.
- **Stop policy (§8):** writer failure, timeout, or an unsealed phase
  parks the run — rescue branch for uncommitted work, state →
  `blocked` with the exact cause, rendered stop report with a cleanup
  list. Nothing is simply aborted.
- **Sealing:** the writer lane seals its phase via
  `state.sh transition <phase> done`; the runner verifies the seal and
  refuses to advance without it.

The runner never edits `state.json` or `findings.json` directly — all
writes go through `scripts/state.sh` and `scripts/ledger.mjs`.
