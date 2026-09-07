# Installation

## Codex

From the repository root:

```bash
./scripts/install-codex.sh
```

This copies the bundled chain into:

```text
~/.codex/skills/
```

## Claude

From the repository root:

```bash
./scripts/install-claude.sh
```

This copies the bundled chain into:

```text
~/.claude/skills/
```

## Ponytail (required for framework runs, Stage 2)

The framework's minimalism ladder is the third-party
[Ponytail](https://github.com/DietrichGebert/ponytail) plugin — installed
on BOTH providers, same version, mode `full`. The P0 preflight
(`ponytail-check.sh`) blocks runs on absence or version/mode mismatch.

```bash
# Claude Code
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail
# Codex
codex plugin marketplace add DietrichGebert/ponytail
codex plugin add ponytail@ponytail
```

The shared mode lives in `~/.config/ponytail/config.json`
(`{"defaultMode":"full"}` — `ponytail-check.sh` persists it if absent).
Leave `PONYTAIL_SUBAGENT_MATCHER` unset. Ponytail then reaches every normal
subagent, including generic implementation fallbacks; P0 rejects a scoped
matcher because it silently misses those fallbacks.

`PONYTAIL_ENFORCE=0` is the loud escape hatch — the run continues without
the ladder, recorded in state.json and flagged in the reports.

## Notes

Framework helpers in a project are versioned snapshots of the installed skills.
P0 and every implementation start/resume run the installed synchronizer before
workers start:

```bash
node ~/.codex/skills/4b_setup/scripts/sync-framework.mjs
# Claude: node ~/.claude/skills/4b_setup/scripts/sync-framework.mjs
```

Run from the PROJ worktree root, or pass `--target /path/to/worktree`.
`--check` reports freshness without changing project files. The generated
`.skillchain-helpers.json` records installed-source and project-file hashes;
commit it with the helpers. Untouched copies update automatically. Existing
different files without a baseline, local edits, or upstream changes to reviewed
adaptations require reconciliation. After merging and testing each such file,
use `--adopt scripts/<file>` to record its reviewed contents. Repeat the option
for multiple files. Adoption is an explicit review acknowledgment, not a merge.
Conflicts prevent the entire refresh from writing project files.

Always invoke the installed synchronizer; a project copy requires an explicit
`--skills-root /path/to/installed/skills`. Refresh only before implementation,
never during a gate. Installation remains explicit: pull this framework and run
the installers to obtain new releases. Sync compares with those installed files,
not a remote branch, and never silently discards project-specific adaptations.

- Existing skill folders with the same names are overwritten.
- The installed folders are copies, not Git repositories. To update another
  machine, pull this skill-chain repository there and run both installers
  again; do not try to push from `~/.claude/skills/` or `~/.codex/skills/`.
- Re-running the installers also refreshes the shared P0/P8 worktree helper,
  the plan-consistency validator, and the provider-specific Wave Gate.
- The 0-to-8 core chain and its `cross-review` mechanism are installed, along with the documented optional skills: `bugfixing`, `refactor-dreamer`, `sonar-cli`, `supabase-local-dev`, and `vibecoder`.
- `CLAUDE.md` is not installed as a skill. It is a repo-level pointer file only.

## Updating an existing PROJ for the optimized gates

Refresh before starting/resuming implementation, with workers and gates stopped.
The helper inventory includes `quality-evidence.mjs` alongside `wave-gate.sh`
and `quality-gate-proof.sh`. Commit the synchronized helper set and manifest
together. If repository-wide lint includes generated framework scripts, extend
its existing exclusions for newly introduced helpers using the P0 preflight
inventory; syncing files alone does not change lint configuration.

Build/coverage reuse is opt-in. Declare real output paths in `build_artifacts`
and, for separate coverage, `coverage_cmd` plus `coverage_artifacts`. The
configured `sonar_cmd` must then scan without running coverage again. Do not
also declare the same coverage command as a quality-phase test. Projects without
these options continue running their existing commands without artifact reuse.

Old markdown-only PROJ gate statuses cannot satisfy the new proof checker.
Generate current evidence through `quality-evidence.mjs`; do not fabricate or
copy success records from an earlier run. The [execution guide](executing-skill.md#proj-quality-gate)
describes the commands and invalidation rules. An already-running agent is not
updated mid-gate; resume with the refreshed skill instructions and helper set.
