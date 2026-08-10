# Runner — Host-Neutral Dual-Lane Phase Runner (Stage 1 + Stage 2)

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
| `spike-stage2.sh` | Stage 2 release gate: bundle determinism/budgets/projection parity, injector tier matrix, symmetric authenticated cross-review (including six-persona QA, structured Claude output, and 10 MB transport failure), P7 runner gate |
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
  `codex exec --sandbox read-only`; the P6 finder additionally gets
  `Bash` to run tests, with a working-tree integrity check after it).
  Peer findings are ingested into the ledger; a failed peer never stops
  the run — but a failed or timed-out WRITER cancels the peer
  immediately, and SIGINT/SIGTERM kill both lane process groups.
- **P6 is sequential:** the read-only QA finder runs FIRST and its
  findings are ingested before the P6 controller starts; the runner
  refuses `P6:done` while the ledger has open Critical/High findings.
- **Models are pinned:** the claude writer runs `CLAUDE_WRITER_MODEL`
  (default `opus`), review lanes run `CLAUDE_REVIEW_MODEL` (default
  `sonnet`); both are recorded per lane in state.json and the runner
  refuses to start when they are equal — degraded "model-opposite" must
  actually be a different model.
- **Degraded mode is never silent:** codex missing or unauthenticated →
  single-provider run with the model-opposite reviewer; `degraded` is
  set in state.json and rendered into the morning report and PR body.
- **Stop policy (§8):** writer failure, timeout, or an unsealed phase
  parks the run — the rescue branch is built through a temporary git
  index (the working tree, including state.json and lane outputs, is
  never touched), state → `blocked` with the exact cause, rendered stop
  report with a cleanup list. Nothing is simply aborted.
- **Sealing:** the writer lane seals its phase via
  `state.sh transition <phase> done`; the runner verifies the seal and
  refuses to advance without it.
- **P7 curation gates (Stage 2):** after the P7 seal the runner
  independently re-verifies FORM (`curation-caps.sh` exit 0) and TRUTH
  (no open Critical/High ledger findings from source `cross-review`) —
  sealing past a red gate parks the run, mirror of the P6 gate.
- **Context bundles (Stage 2):** P5/P7 writer prompts carry a POINTER to
  `specs/.../context/` — bundle text is never pasted; Claude subagents
  get their type-scoped bundle via the SubagentStart hook
  (`context-injector.mjs claude`), codex lanes read
  `bundle-<role>.codex.md`. Both providers receive the same canonical
  bundle hash.
- **Ponytail coverage (Stage 2):** the runner clears
  `PONYTAIL_SUBAGENT_MATCHER`, using Ponytail's native all-subagent path;
  P0 blocks any scoped matcher because it can miss generic implementation
  fallbacks. Version and mode parity remain gated in `ponytail-check.sh`.

Env knobs: `CLAUDE_WRITER_MODEL`, `CLAUDE_REVIEW_MODEL`, `PEER_GRACE`
(seconds a peer may outlive the writer, default 300),
`PONYTAIL_ENFORCE` (0 = loud escape hatch for the P0 ponytail gate),
`CONTEXT_BUNDLE_BUDGET` (token budget override for the compiler).

The runner never edits `state.json` or `findings.json` directly — all
writes go through `scripts/state.sh` and `scripts/ledger.mjs` (both
serialize concurrent writes via locks and validate against the schema
contract on every write).
