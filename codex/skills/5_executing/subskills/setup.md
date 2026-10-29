# Setup — P0 Subskill of Executing (runs as a subagent)

Write generated artifacts, decision logs, reports and handoff prompts in English; converse with the user in their language.

Owns the P0 phase of the agent workflow (CONCEPT.md §4). This is a
subskill of `5_executing`, not a standalone skill: the Step 5 lead
(`5b_executing-large-model` by default, or `5_executing`) spawns ONE subagent with this file as its instructions once
state.json reads `CP1:approved` (or a P0 resume state); the phase
runner's P0 lane loads it directly. Setup happens ONCE per PROJ, before
any implementation, so implementer lanes start with a clean branch,
verified tools, and a machine-readable state file.

P0 is script-driven: run the scripts and record their results. Bounded
judgment validates the ground file (step 5a) and selects a safe fallback
negative control when no auth budget is configured. There are no user questions in P0.


**Split-helper upgrades:** sync backs up the unchanged retired monolith to
`scripts/plan.mjs.pre-split`. Keep that backup for review, then remove it manually
after verification. A modified, adopted or unknown old helper blocks sync:
rename it to that backup path, sync fresh helpers, transfer relevant changes,
run tests and `chain sync --adopt <new-path>` for every reviewed adaptation.
Do not start a PROJ until this is complete. If copies from before consolidation
already occupy the new paths, back them up under other names first and follow
the same sync/transfer/test/adopt procedure; never adopt old copies blindly.

## Subagent Contract

- **Input from the orchestrator:** `<X> <theme>` and the control checkout
  path. Everything else is on disk.
- **Never ask the user.** The two prompts below (missing design system,
  legacy folder layout) take their stated default — skip / keep the
  existing layout — are recorded in `5_progress/PROJ-<X>-progress.md`,
  and are listed in the return so the orchestrator can relay them.
- **Return ≤ 300 tokens:** final `phase:status`, `.worktree.path`,
  branch, `base_sha`, `degraded`, the stop reason when blocked, and the
  defaulted decisions. Logs stay in this context.

## Codex Adaptation

This subskill is aligned with the Claude variant. In Codex:

- Do not require `claude --dangerously-skip-permissions` or
  `bypassPermissions` for THIS session. Use the current Codex session
  permissions and the normal approval/sandbox policy; there is no
  permission-merge step. (The preflight installs no hook and does not touch
  `.claude/settings.json`.)
- Reusable skill assets live under `~/.codex/skills/...` instead of
  `~/.claude/skills/...`.
- The preflight itself is host-neutral: `claude` stays a HARD tool
  (it hosts the phase chain) and `codex` stays degradable, regardless
  of which CLI runs this subskill.

## Input

- `specs/PROJ-<X>-<theme>/state.json` at `CP1:approved` (sealed by the
  **checkpoint** subskill at Checkpoint 1)
- `specs/PROJ-<X>-<theme>/3-4_plan/` — wave plans + `wave-gate-config.json`

## External handoff setup

When `external-handoff.json` exists, read [the receiving input contract](../../2e_handoff-refinement/references/input-contract.md). Before state changes or worktree creation, run `chain check inputs <project-directory>` using the installed helper if necessary. Verify the pinned bundle is self-contained, accepted for this repository and consistent with CP1. Missing/tampered inputs, unresolved product scope or missing dependency evidence return a blocker; P0 cannot decide product answers or infer acceptance.

Set up only this repo's checkout/worktree and state. Other repositories keep separate runs. Reuse the actual bound app workspace; do not launch a session in the coordination checkout with instructions merely to `cd` elsewhere. Preserve the pinned source bundle through setup and normal framework sync; never generate replacement PRDs to satisfy the local-format gate.

## Workflow

### 0. Gate on approval

<HARD-GATE>
Read the state with the repo helper, or directly with the installed helper when
the repo copy is not present yet:
`bash ${CHAIN:-~/.codex/skills/5_executing/scripts/chain} state get <X> <theme> '.phase + ":" + .status'`.
Do not copy a missing helper into the control checkout before `prepare`; that
would correctly trip its clean-checkout gate.

- `CP1:approved`, `P0:running`, `P0:blocked`, `P0:done` (refresh) → proceed;
  step 1 handles each resume state.
- state.json missing or any other phase/status → STOP and return
  `not approved` — the orchestrator runs the **checkpoint** subskill
  first. P0 never runs on an unapproved plan.

Before changing state or creating a worktree, run the plan consistency gate:

```bash
PLAN_DIR=specs/PROJ-<X>-<theme>/3-4_plan
[ -d "$PLAN_DIR" ] || PLAN_DIR=specs/PROJ-<X>-<theme>/6_plan
bash ~/.codex/skills/5_executing/scripts/chain check plan "$PLAN_DIR"
```

Any non-zero exit is a hard stop: route back to **writing-plans**. For a
legacy PROJ, select the existing `6_plan/` directory as above; never create a
parallel current-layout directory. `chain worktree prepare` repeats this exact
validation before it creates anything.
</HARD-GATE>

### 1. Persistent PROJ worktree + BASE_SHA

**Protected changes in the supplied control checkout:** keep them untouched.
Do not stash, discard, or commit unrelated edits to satisfy the clean gate.
Instead, use a separate clean detached control worktree at the explicitly
identified, committed CP1-approved SHA. Approval in the working copy alone is
insufficient: confirm that this commit contains the approved plans and sealed
`CP1:approved` state. If those exist only as uncommitted changes, stop and return
to the checkpoint lead to seal and commit only the authorized CP1 artifacts.

From the supplied checkout root, substitute the approved commit and a new,
unoccupied absolute sibling path, then run:

```bash
ORIGINAL_CONTROL=$(git rev-parse --show-toplevel)
CP1_SHA=$(git rev-parse --verify '<approved-commit>^{commit}') || exit 1
git show "$CP1_SHA:specs/PROJ-<X>-<theme>/state.json" |
  jq -e '.phase == "CP1" and .status == "approved"' >/dev/null || exit 1
CLEAN_CONTROL=/absolute/path/to/repo-cp1-control
git worktree add --detach "$CLEAN_CONTROL" "$CP1_SHA" || exit 1
cd "$CLEAN_CONTROL" || exit 1
[ -z "$(git status --porcelain)" ] || exit 1
```

Repeat step 0's plan consistency gate in this clean checkout, then run the
ordinary `prepare` below; its clean-checkout gate remains mandatory. Ignored
local environment files are not copied by Git: satisfy the existing environment
requirements without printing secrets or copying unrelated changes. Record the
original checkout, detached control path, and approved SHA in `progress.md` in
the resulting PROJ worktree. The helper records the clean control path as
`.worktree.control_path`. Keep both new worktrees through the normal delivery
cleanup; the PROJ worktree can depend on its control checkout's environment.

The default target uses the **control directory's basename**, so a control named
`repo-cp1-control` produces `repo-cp1-control-proj<X>`, not `repo-proj<X>`.
Do not guess the PROJ path: the returned path and recorded `.worktree.path` are
authoritative, including on resume. Reuse the same clean control checkout for
P0 retries; do not create another control checkout or retarget the base tag.

From the clean control checkout root (the supplied checkout if already clean), run:

```bash
WORKTREE=$(~/.codex/skills/5_executing/scripts/chain worktree prepare <X> <theme>)
cd "$WORKTREE"
P0_STATE=$(bash ~/.codex/skills/5_executing/scripts/chain state get <X> <theme> '.phase + ":" + .status')
case "$P0_STATE" in
  CP1:approved|P0:blocked) bash ~/.codex/skills/5_executing/scripts/chain state transition <X> <theme> P0 running ;;
  P0:running) : ;; # interrupted P0 resumes without a duplicate transition
  P0:done) P0_ALREADY_DONE=1 ;; # refresh-only; never transition or reseal
  *) echo "unexpected P0 resume state: $P0_STATE" >&2; exit 1 ;;
esac
```

Use the installed absolute `chain` path until the synchronization below has installed the helper set; `scripts/chain state` is not assumed to exist at CP1. The synchronized, committed repo helpers are then canonical for the run.

When `P0_ALREADY_DONE=1`, synchronize and validate the helpers, then commit any refresh separately; skip all phase transitions and the P0 seal commit.

`prepare` requires a clean control checkout at its committed CP1 `HEAD`,
creates `proj/PROJ-<X>` at that exact commit, and tags
`proj-PROJ-<X>-base`. The default persistent path is the sibling
`<parent>/<repo>-proj<X>`; `SKILLCHAIN_WORKTREE_ROOT` overrides the parent.
An existing correctly registered branch/path is resumed idempotently. A dirty
control checkout, mismatched existing branch, conflicting registration, or
occupied target path is a hard stop.

`.env.local` is linked from the control checkout only when the source exists
and Git ignores it. If only `.env.local.example` exists, stop and require the
local secret file. Secret values are never printed or stored. Dependencies are
installed reproducibly from the one supported lockfile inside the worktree;
`node_modules` is never linked. With `app_root` in `wave-gate-config.json` (a nested
app, e.g. `app`), the lockfile, install, preflight package-manager check and
wave-gate registry check all use that directory. `worktree_links` (`[{path, target}]`,
git-ignored `path`) recreates ignored dev-asset symlinks, e.g. a prototype's
`node_modules` -> `app/node_modules`, after the install. The helper records `.worktree` metadata,
`.base_sha`, and `.branch` through `chain state`, including shared database mode,
dev port (`SKILLCHAIN_DEV_PORT` or `frontend.dev_url`), and cleanup status.

Database migrations and auth-consuming commands must run through the shared
resource lock:

```bash
scripts/chain worktree with-shared-lock -- <command...>
```

The default lock lives in the Git common directory and therefore serializes
parallel worktrees of this repository. Set
`SKILLCHAIN_SHARED_RESOURCE_LOCK` to an explicit shared path to override it.

The helper defaults to **exclusive** for compatibility. Optional
`with-shared-lock --shared --timeout <seconds> -- <command>` allows independent
test lifecycles to overlap on that same file while still excluding migrations.
Use it only after proving fixture/actor isolation; it is not an automatic
read-only SQL classifier. Migrations, resets and global fixture changes retain
the default exclusive mode across every worktree. Do not split migration and
test locks: that would allow schema changes during tests. The lock does not
establish schema-version compatibility or FIFO migration order.

Record the lock's actual path, acquisition layer, wait budget and DB/browser
owner in the runtime constraints. Preserve exit 73 through project wrappers;
an outer command timeout must not obscure the lock wait. Browser probes close
their named session on every exit, inside the owned resource window; their
daemon can retain fd 8 after the opening command returns. Keep DB-backed tests
and browser runs serialized when they share fixtures. Execution's
`references/worker-lifecycle.md` describes diagnosis and handover.

Before running any repo preflight, synchronize from the installed skill tree:

```bash
bash ~/.codex/skills/5_executing/scripts/chain sync
```

A non-zero exit blocks setup until the reported helper differences are reconciled. The command plans the whole inventory before copying anything; unrecognized or modified project copies are never overwritten. Compare each conflict with its installed source, merge the needed upstream changes while preserving project adaptations, test the result, then rerun with `--adopt scripts/<reviewed-file>` (repeat the option for multiple files). Do not adopt stale code to bypass an update. No separate user confirmation is required for an already-authorized helper refresh.

After synchronization succeeds and all conflicts are reconciled, validate every
wave against the synchronized project roles (`templates/roles/`) without an override:

```bash
bash scripts/chain render context check <X> <theme>
```

This mandatory check blocks setup on failure. Step 4 and CP1 checked installed
roles before P0; their green result does not validate project role adaptations.
Resolve role compatibility or budget failures and rerun this default check before
continuing. Never use `--roles-dir` to bypass this gate.

### 2. CodeRabbit config preflight

If `coderabbit.enabled` is `false` in `wave-gate-config.json`, skip this step
and copy nothing. Otherwise, if `.coderabbit.yaml`/`.coderabbit.yml` is missing
at repo root, copy
`~/.codex/skills/5_executing/references/coderabbit-template.yaml` to
`.coderabbit.yaml` and include it in the setup commit.

### 3. Tool + auth preflight

Run `bash scripts/chain check preflight <X> <theme>` (before step 3 has synced
`scripts/`, `~/.codex/skills/5_executing/scripts/chain check preflight <X> <theme>`
runs the same gate from the installed skill tree — `chain` finds the sibling
helpers there). It checks
the CONCEPT.md §7 CLI list including auth states and a bounded live
probe per provider (claude hard, codex degradable) and writes the
`preflight` block into state.json:

- Exit 0 → continue. If it reports DEGRADED (codex missing or
  unauthenticated), the run continues single-provider — `degraded` is
  now set in state.json and every review falls back to MODEL-opposite.
  Never work around this flag and never unset it by hand.
- Exit 1 → hard tool missing = **stop condition (§8)**: transition to
  blocked (`bash scripts/chain state transition <X> <theme> P0 blocked`),
  write the stop report, do not continue.

For a repo with `supabase/migrations/`, preflight also runs
`chain check migrations`: every git worktree of this repo shares ONE local
Supabase Postgres instance, so another worktree may have applied migrations
absent from this worktree's own `supabase/migrations/` folder — code and
grants here would then silently run against a schema this branch never
declared. That is a stop condition too (fix: `supabase db reset` from this
worktree); a worktree merely having *pending* local migrations is normal and
not flagged. `chain gate wave` re-runs the same check at the start of every
wave, since a wave can run long after P0 in a repo another worktree has
since advanced.

Preflight also reports the repo's **structure state** — a missing
`docs/components.md`, a still hand-written one, a missing or oversized
`docs/DESIGN-SYSTEM.md`. This is a backstop: the decision belongs to
`1b_visual-companion`, which records it under `## Design System State` in
`layout-decision.md`. If that record exists, honour it and do not re-ask.
None of these is a stop condition — repos predating the design system, and
backend-only repos, run unchanged. Only for a repo that never went through UI
discovery, put it to the user as a decision instead of acting on it:

> "This chain expects `docs/DESIGN-SYSTEM.md` (design rules, ≤80 lines) —
> this repo has none. Create it now via `1c_frontend-design`, or skip and
> proceed without design rules?"

Skipping is a valid answer; record it and continue. Only the hand-written
registry needs a real migration (move the purpose texts into doc blocks above
the exports, then `--force`), and even that is optional — the generator
refuses to overwrite the file, and the wave gate reports the pending
migration without blocking.

### 4. Verify synchronized framework scripts + templates

The synchronizer in step 1 installs this inventory and records source/project SHA-256 hashes in `.skillchain-helpers.json`. Verify it before sealing P0:

```bash
bash ~/.codex/skills/5_executing/scripts/chain sync --check
```

Commit the manifest and changed helpers/templates with setup. Do not manually overwrite an older helper. Unmodified managed copies update automatically; reviewed adaptations survive until their installed source or local bytes change, at which point reconciliation is required. Run only at setup/resume boundaries, never during a gate or while workers are editing these files.

| From (installed skill) | To |
|---|---|
| `2_requirements-engineer/scripts/validate-prds.mjs`; `3_architecture/scripts/validate-architecture.mjs` | `scripts/` |
| `4_writing-plans/scripts/validate-wave-plan.mjs`, `document-parser.mjs`; `3_architecture/scripts/architecture-parser.mjs` | `scripts/` |
| `5_executing/scripts/chain`, `resolve-inputs.mjs`, `render.mjs`, `compile-context.mjs`, `story-slice.mjs`, `state.sh`, `preflight.sh`, `env-local.sh`, `worktree.sh`, `migration-drift-check.sh`, `sync-framework.mjs` | `scripts/` |
| `5_executing/manifests/roles/*.md` | `templates/roles/` |
| `5_executing/templates/decisions.md.tmpl`, `morning-report.md.tmpl`, `stop-report.md.tmpl` | `templates/` |
| `cross-review/scripts/cross-review.sh`, `review-with-claude.sh`, `review-with-codex.sh` | `scripts/` |
| `cross-review/templates/cross-review-prompt.md.tmpl` | `templates/` |
| `6_qa/scripts/findings.mjs`, `findings-store.mjs` | `scripts/` |
| `7_documentation/scripts/curation.sh` | `scripts/` |
| `5_executing/templates/agent-md-entry.md.tmpl` | `templates/` |
| `8_delivery/scripts/delivery.sh` | `scripts/` |
| `8_delivery/templates/pr-body.md.tmpl` | `templates/` |
| `5_executing/scripts/wave-gate.sh`, `quality.mjs`, `gen-component-registry.mjs` | `scripts/` (as today) |

`chmod +x` the shell scripts.

After copying, preflight merges the framework-owned files into Biome's
`files.ignore` (or creates `biome.json`) and adds `.state.lock` to
`.gitignore`. This preserves target linting for target code while keeping the
versioned framework helpers available for the run.

Before committing the copied files, run the target's existing lint command
when it has one (`npm run lint --if-present`, or its configured equivalent)
and `bash scripts/chain render registry --check` when component folders
exist (nested app: `bash scripts/chain render registry <app_root> --out docs/components.md --check`). Exit 3 means a hand-written or safety-refused registry: report it and
do not overwrite it; any other non-zero registry result must be fixed before
P0 is sealed.

### 4a. Verify the verifier

Before trusting an unattended run, prove one applicable gate can reject a
controlled bad change. When `auth_budget` is configured, its project hooks must
honor `SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL=1` without consuming a hosted
identity. After step 4 verifies the synchronized gate, first commit what the setup has
written so far (synced helpers, templates, manifest, state) as a checkpoint:
`chore(PROJ-<X>): P0 checkpoint — framework scripts`. The ordinary fallback
control below runs `chain gate wave --ac-only`, which refuses a dirty working
tree; the clean-tree check is not relaxed for it. Then run:

```bash
CONTROL_WAVE=$(jq -r '.waves | keys | map(tonumber) | min' "$PLAN_DIR/wave-gate-config.json")
EXPECTED_AUTH_RC=$(jq -r '.auth_budget.exhausted_exit_code // 75' "$PLAN_DIR/wave-gate-config.json")
set +e
bash scripts/chain gate wave --auth-budget-negative-control "$CONTROL_WAVE" <X> <theme>
CONTROL_RC=$?
set -e
[ "$CONTROL_RC" -eq "$EXPECTED_AUTH_RC" ]
jq -e --argjson code "$EXPECTED_AUTH_RC" \
  '.ralph_status == "infrastructure_failed" and .infrastructure_failure.exit_code == $code' \
  "specs/PROJ-<X>-<theme>/5_progress/ralph-wave-${CONTROL_WAVE}.json"
```

This exercises `preflight_cmd` and, when configured, `rate_limit_evidence_cmd`
through the real shared-lock/runtime path and must produce retained non-empty
evidence. It is the required negative control for an auth-budget project. For a
project without `auth_budget`, pick the cheapest safe control: temporarily break
an AC assertion, authorization/RLS policy, or the build; run its real gate red,
restore the exact file, and re-run it green. Record the command, expected red
reason, retained evidence, and restored green result under `## Negative controls`
in `5_progress/PROJ-<X>-progress.md`. Never use a production mutation, destructive
migration, or syntax-only failure. If no safe control exists, STOP; an untested
verifier is not a P0 success.

### 4b. Static-check candidates (suggest only)

Read `docs/ARCHITECTURE.md` § Stack and, per optional key in
`wave-gate-config.json` (`complexity_cmd`, `arch_rules_cmd`, `mutation_cmd`),
**suggest** one candidate command for that stack when the config lacks the key
(complexity/duplication rules, dependency-direction rules, mutation testing).
Install nothing and edit no config: the thresholds live in the project's own tool
config, and the decision is the user's. Record the suggestions and the default
taken (key left absent = silently skipped) under the defaulted decisions in
`5_progress/PROJ-<X>-progress.md`, and relay them in the return.

### 5. Worker context (compile worker files, ground file)

**5a. Generate the ground file** — bounded assumption validation in P0.
Write `specs/PROJ-<X>-<theme>/ground-file.md`: assumptions the plans rely
on (stack versions, conventions, data-model facts), each VALIDATED
against the codebase, and ONLY what `docs/` does not already state (§5
redundancy rule — the ground file never duplicates curated docs). It comes
before the compile, so the worker files carry it from the first run.

**5b. Compile the worker files for every wave** (once, after the ground file).

```bash
bash scripts/chain render context compile <X> <theme>
```

Without `--wave` every wave compiles on its own (there is no merged
cross-wave view): `context/workers/wave-N/<US-ID>.md` per story (the role comes
from the plan table's `Agent Type`; `Split: contract` gives `.backend.md` and
`.frontend.md`) and `context/roles/wave-N/<role>.md` per role without a story
(reviewer, Quality-Gate fix workers). Step 5 recompiles `--wave N` at each wave
start. CP1 checked installed roles; P0 checks the synchronized project roles.
A failure here can also come from project role adaptations, changed sources, or
the ground file pushing a role over its budget. Resolve the reported cause before
sealing P0.

- A role over its manifest budget aborts `compile` with exit 1 (role, tokens,
  budget) before anything is written. Condense that role's sources, or raise
  only its manifest budget when its documented scope genuinely requires it.
  Story size is reported, not capped. Exit 2 = unresolvable plan folder or story.
- Nothing is recorded in `state.json`: no lock, no hash bookkeeping, no `chain state set` (each file's first line carries a shortened plan hash).
  `compile` is idempotent; an I/O error exits 1 — fix the cause and rerun it.
- The compiler also rewrites `.claude/agents/skillchain-<role>.md` agent files
  for the Claude lanes the runner will start — only `skillchain-*` files are ever written, existing agents
  are never touched — and sweeps up leftovers of the old layout (`bundle-*`,
  `bundles.lock.json`, `blocked-roles.json`).

**5c. Delivery — there is nothing to activate.** No hook: the lead (or the
runner's lane prompt) names the worker file by path in each spawn prompt, and the
worker reads it first. `chain check preflight` installs nothing into
`.claude/settings.json`. (`merge-project-settings.sh`, which merges the
execution permission allowlist into `.claude/settings.json`, exists only in the
Claude tree and is not a Codex step.) Never paste file contents into spawn
prompts. After `sync` the lead runs `compile --wave N` in the same step; no worker
starts in between (lead discipline: a worker holding a path to an outdated file is
not caught).

### 6. Seal P0

1. `bash scripts/chain state transition <X> <theme> P0 done`
2. Commit everything not yet in the checkpoint commit on the PROJ branch:
   `chore(PROJ-<X>): P0 setup — branch, preflight, framework scripts, worker context files`

→ RETURN to the orchestrator with the summary from the Subagent Contract.
It continues with execution — either the phase runner
(`runner/run-phase.sh P5 <X> <theme>`, autonomous dual-lane) or the
Step 5 wave loop directly in its session.

When P0 is runner-managed, the runner detects the registered PROJ worktree,
re-executes itself there once, and starts every later phase from that path. The
`SKILLCHAIN_WORKTREE_REEXEC` guard prevents a re-exec loop.

## Completion Checklist

- [ ] state.json was `CP1:approved` before starting; now `P0:done`
- [ ] wave plan consistency validator passed before worktree creation
- [ ] persistent `proj/PROJ-<X>` worktree exists; `base_sha`, `branch`, and `.worktree` metadata are in state.json
- [ ] `.env.local` is an ignored control-checkout symlink (or explicitly absent); dependencies are isolated
- [ ] `preflight` block in state.json; `degraded` set truthfully
- [ ] `specs/.../context/` has `workers/wave-N/` (one file per story) and `roles/wave-N/` for every wave; nothing recorded in state.json
- [ ] `ground-file.md` written (only assumptions docs/ does not state)
- [ ] `scripts/` + `templates/` contain the framework copies, executable
- [ ] `.coderabbit.yaml` present at repo root (not required when `coderabbit.enabled=false`)
- [ ] One safe negative control was observed red, restored, and recorded
- [ ] Setup committed on the PROJ branch: the checkpoint commit before the negative control, then the seal commit

## Failure Behavior

Any hard preflight failure or git error is a stop condition (§8): state
→ `P0:blocked` with the exact cause in `.stop.reason`, stop report
written, nothing half-configured left silently in place. P0 is
idempotent — after fixing the cause, re-run this subskill; completed steps
(existing branch, identical script copies) are skipped, not duplicated.

Legacy PROJ folders: see `0_chain-guide/references/legacy-layout.md`.
