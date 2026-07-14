---
name: setup
description: "Run P0 setup for an approved PROJ: preflight all required CLIs and auth states, create the proj/PROJ-X branch with BASE_SHA tag, copy the framework scripts and templates into the repo, and extend state.json for the execution phases. Use when: (1) Checkpoint 1 approval is sealed in state.json (CP1:approved) and execution has not started, (2) preflight must be re-run after fixing a stop condition, (3) the framework scripts in the repo need refreshing from the installed skills. Not for: architecture/plan approval (use checkpoint), implementing stories (use executing), PR delivery (use delivery)."
---

# Setup — P0 Once Per PROJ, Fully Automatic

Owns the P0 phase of the agent workflow (CONCEPT.md §4). This skill
replaces the FIRST-ACTION preflight block that used to live inside
Skill 5: setup happens ONCE per PROJ, before any execution session,
so implementer lanes start with a clean branch, verified tools, and a
machine-readable state file.

Everything here is deterministic — run the scripts, record the results.
There are no judgment calls and no user questions in P0.

## Codex Adaptation

This skill is aligned with the Claude variant. In Codex:

- Do not require `claude --dangerously-skip-permissions`,
  `.claude/settings.json`, or `bypassPermissions`. Use the current Codex
  session permissions and the normal approval/sandbox policy; there is
  no permission-merge step.
- Reusable skill assets live under `~/.codex/skills/...` instead of
  `~/.claude/skills/...`.
- The preflight itself is host-neutral: `claude` stays a HARD tool
  (it hosts the phase chain) and `codex` stays degradable, regardless
  of which CLI runs this skill.

## Input

- `specs/PROJ-<X>-<theme>/state.json` at `CP1:approved` (sealed by
  **checkpoint** at Checkpoint 1)
- `specs/PROJ-<X>-<theme>/6_plan/` — wave plans + `wave-gate-config.json`

## Workflow

### 0. Gate on approval

<HARD-GATE>
Read the state: `bash scripts/state.sh get <X> <theme> '.phase + ":" + .status'`
(if `scripts/state.sh` is missing, copy it from
`~/.codex/skills/4b_setup/scripts/state.sh` first).

- `CP1:approved` → proceed.
- state.json missing or any other phase/status → STOP. Route to
  **checkpoint** (4a) — P0 never runs on an unapproved plan.
</HARD-GATE>

Then mark the phase: `bash scripts/state.sh transition <X> <theme> P0 running`

### 1. Branch + BASE_SHA

1. `git checkout -b proj/PROJ-<X>` (from the current main HEAD)
2. `BASE_SHA=$(git rev-parse HEAD)`; tag it: `git tag proj-PROJ-<X>-base`
3. Record both:
   `bash scripts/state.sh set <X> <theme> .base_sha "$BASE_SHA"`
   `bash scripts/state.sh set <X> <theme> .branch proj/PROJ-<X>`

### 2. CodeRabbit config preflight

If `.coderabbit.yaml`/`.coderabbit.yml` is missing at repo root, copy
`~/.codex/skills/5_executing/references/coderabbit-template.yaml` to
`.coderabbit.yaml` and include it in the setup commit.

### 3. Tool + auth preflight

Run `bash scripts/preflight.sh <X> <theme>` (copy from
`~/.codex/skills/4b_setup/scripts/preflight.sh` if missing). It checks
the CONCEPT.md §7 CLI list including auth states and a bounded live
probe per provider (claude hard, codex degradable) and writes the
`preflight` block into state.json:

- Exit 0 → continue. If it reports DEGRADED (codex missing or
  unauthenticated), the run continues single-provider — `degraded` is
  now set in state.json and every review falls back to MODEL-opposite.
  Never work around this flag and never unset it by hand.
- Exit 1 → hard tool missing = **stop condition (§8)**: transition to
  blocked (`bash scripts/state.sh transition <X> <theme> P0 blocked`),
  write the stop report, do not continue.

### 4. Copy framework scripts + templates into the repo

The repo copy is canonical for the run — versioned, testable outside
sessions, identical on every machine. Copy from the installed skills
into `scripts/` and `templates/` at repo root (skip byte-identical
files; overwrite older copies and note it in the commit):

| From (installed skill) | To |
|---|---|
| `4b_setup/scripts/state.sh`, `preflight.sh` | `scripts/` |
| `4a_checkpoint/templates/decisions.md.tmpl` | `templates/` |
| `6_qa/scripts/ledger.mjs`, `harvest-debt.sh` | `scripts/` |
| `8_delivery/scripts/conflict-probe.sh`, `render-pr-body.mjs`, `ci-poll.sh` | `scripts/` |
| `8_delivery/templates/pr-body.md.tmpl` | `templates/` |
| `5_executing/scripts/wave-gate.sh` | `scripts/` (as today) |

`chmod +x` the shell scripts.

### 5. Stage 2 items (not yet active — do NOT improvise them)

- Context pack check + bundle compilation (`compile-context-bundles.mjs`)
- Ground file generation (`ground-file.md`)
- Provider context-injector adapters (SubagentStart hook / Codex hook)
- Ponytail install + parity check across active providers

Log one line in progress.md that these were skipped as Stage 2.

### 6. Seal P0

1. `bash scripts/state.sh transition <X> <theme> P0 done`
2. Commit everything from steps 1–4 on the PROJ branch:
   `chore(PROJ-<X>): P0 setup — branch, preflight, framework scripts`

→ NEXT ACTION: start execution — either the phase runner
(`runner/run-phase.sh P5 <X> <theme>`, autonomous dual-lane) or the
**executing** skill (5) directly in this session.

## Completion Checklist

- [ ] state.json was `CP1:approved` before starting; now `P0:done`
- [ ] `proj/PROJ-<X>` branch exists; `base_sha` + `branch` in state.json
- [ ] `preflight` block in state.json; `degraded` set truthfully
- [ ] `scripts/` + `templates/` contain the framework copies, executable
- [ ] `.coderabbit.yaml` present at repo root
- [ ] One setup commit on the PROJ branch

## Failure Behavior

Any hard preflight failure or git error is a stop condition (§8): state
→ `P0:blocked` with the exact cause in `.stop.reason`, stop report
written, nothing half-configured left silently in place. P0 is
idempotent — after fixing the cause, re-run this skill; completed steps
(existing branch, identical script copies) are skipped, not duplicated.
