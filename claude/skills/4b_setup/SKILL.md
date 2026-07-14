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

P0 is script-driven — run the scripts, record the results — with exactly
ONE bounded judgment step: the ground file (step 6b, context-curator
judgment). There are no user questions in P0.

## Input

- `specs/PROJ-<X>-<theme>/state.json` at `CP1:approved` (sealed by
  **checkpoint** at Checkpoint 1)
- `specs/PROJ-<X>-<theme>/6_plan/` — wave plans + `wave-gate-config.json`

## Workflow

### 0. Gate on approval

<HARD-GATE>
Read the state: `bash scripts/state.sh get <X> <theme> '.phase + ":" + .status'`
(if `scripts/state.sh` is missing, copy it from
`~/.claude/skills/4b_setup/scripts/state.sh` first).

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

### 2. Permission preflight (Claude host)

Verify Claude Code was started with `--dangerously-skip-permissions`, or
run `bash scripts/merge-project-settings.sh` once per project (copy from
`~/.claude/skills/5_executing/scripts/merge-project-settings.sh` if
missing) so the allowlist + `defaultMode: bypassPermissions` are in
place. Without this, overnight runs die on the first permission prompt.

### 3. CodeRabbit config preflight

If `.coderabbit.yaml`/`.coderabbit.yml` is missing at repo root, copy
`~/.claude/skills/5_executing/references/coderabbit-template.yaml` to
`.coderabbit.yaml` and include it in the setup commit.

### 4. Tool + auth preflight

Run `bash scripts/preflight.sh <X> <theme>` (if `scripts/` lacks it, copy
the WHOLE 4b_setup helper set first — `preflight.sh`, `ponytail-check.sh`,
`compile-context-bundles.mjs`, `context-injector.mjs`, `state.sh` from
`~/.claude/skills/4b_setup/scripts/` — preflight calls its siblings; a
lone copy also works, it falls back to the installed skill tree). It checks
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

### 5. Copy framework scripts + templates into the repo

The repo copy is canonical for the run — versioned, testable outside
sessions, identical on every machine. Copy from the installed skills
into `scripts/` and `templates/` at repo root (skip byte-identical
files; overwrite older copies and note it in the commit):

| From (installed skill) | To |
|---|---|
| `4b_setup/scripts/state.sh`, `preflight.sh`, `ponytail-check.sh`, `compile-context-bundles.mjs`, `context-injector.mjs` | `scripts/` |
| `4b_setup/manifests/roles/*.md` | `templates/roles/` |
| `4a_checkpoint/templates/decisions.md.tmpl` | `templates/` |
| `3a_cross-review/scripts/cross-review.sh`, `review-with-claude.sh`, `review-with-codex.sh` | `scripts/` |
| `3a_cross-review/templates/cross-review-prompt.md.tmpl` | `templates/` |
| `6_qa/scripts/ledger.mjs`, `harvest-debt.sh` | `scripts/` |
| `7_documentation/scripts/curation-caps.sh` | `scripts/` |
| `0b_intake/scripts/intake-seal-check.sh` | `scripts/` |
| `5_executing/templates/agent-md-entry.md.tmpl` | `templates/` |
| `8_delivery/scripts/conflict-probe.sh`, `render-pr-body.mjs`, `ci-poll.sh` | `scripts/` |
| `8_delivery/templates/pr-body.md.tmpl` | `templates/` |
| `5_executing/scripts/wave-gate.sh` | `scripts/` (as today) |

`chmod +x` the shell scripts.

### 6. Context system (compile bundles, ground file, injectors)

**6a. Compile the context bundles.**

```bash
node scripts/compile-context-bundles.mjs compile <X> <theme>
```

- Exit != 0 = budget breach = **stop condition (§8)** — NOTHING was
  written. Condense `docs/` (move detail into `docs/architecture/`),
  then recompile. Never raise the budget to make it fit.
- Record the hashes in state:
  `bash scripts/state.sh set <X> <theme> .context.bundles "$(jq -c . specs/PROJ-<X>-<theme>/context/bundles.lock.json)"`
- The compiler also projects `.claude/agents/skillchain-<role>.md` agent
  files — only `skillchain-*` files are ever written, existing agents
  are never touched.

**6b. Generate the ground file** — the one bounded judgment step in P0.
Write `specs/PROJ-<X>-<theme>/ground-file.md`: assumptions the plans rely
on (stack versions, conventions, data-model facts), each VALIDATED
against the codebase, and ONLY what `docs/` does not already state (§5
redundancy rule — the ground file never duplicates curated docs). Then
recompile (6a) so the bundles carry it.

**6c. Activate the injector adapters.**

- Claude: the preflight (step 4) already merged the SubagentStart hook
  (`node scripts/context-injector.mjs claude`) and the
  `PONYTAIL_SUBAGENT_MATCHER` env into `.claude/settings.json` —
  deterministic, idempotent, host-neutral. `bash
  scripts/merge-project-settings.sh` additionally merges the execution
  permission allowlist. Subagents then receive their type-scoped bundle
  automatically — never paste bundles into spawn prompts.
- Codex: prompt-file delivery — a codex lane reads
  `specs/.../context/bundle-<role>.codex.md` before implementing
  (`node scripts/context-injector.mjs codex <role> --path`); the
  runner's lane prompts point there.
- Both providers receive the same canonical bundle hash (recorded in
  6a); the injector refuses a stale bundle (hash mismatch → injects
  nothing and warns).

**6d. Ponytail parity** is already gated inside step 4's preflight
(`ponytail-check.sh`: absence or version/mode mismatch across active
providers blocks P0). Never work around a red gate; `PONYTAIL_ENFORCE=0`
is the loud, recorded escape hatch — it lands in state.json and the
reports, never silent.

### 7. Seal P0

1. `bash scripts/state.sh transition <X> <theme> P0 done`
2. Commit everything from steps 1–6 on the PROJ branch:
   `chore(PROJ-<X>): P0 setup — branch, preflight, framework scripts, context bundles`

→ NEXT ACTION: start execution — either the phase runner
(`runner/run-phase.sh P5 <X> <theme>`, autonomous dual-lane) or the
**executing** skill (5) directly in this session.

## Completion Checklist

- [ ] state.json was `CP1:approved` before starting; now `P0:done`
- [ ] `proj/PROJ-<X>` branch exists; `base_sha` + `branch` in state.json
- [ ] `preflight` block in state.json; `degraded` set truthfully
- [ ] `.context.ponytail` in state.json (parity gate result, enforced truthfully)
- [ ] `specs/.../context/` has canonical + claude/codex bundles; `.context.bundles` hashes in state.json
- [ ] `ground-file.md` written (only assumptions docs/ does not state)
- [ ] SubagentStart injector hook merged into project settings (Claude host)
- [ ] `scripts/` + `templates/` contain the framework copies, executable
- [ ] `.coderabbit.yaml` present at repo root
- [ ] One setup commit on the PROJ branch

## Failure Behavior

Any hard preflight failure or git error is a stop condition (§8): state
→ `P0:blocked` with the exact cause in `.stop.reason`, stop report
written, nothing half-configured left silently in place. P0 is
idempotent — after fixing the cause, re-run this skill; completed steps
(existing branch, identical script copies) are skipped, not duplicated.
