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
Scope the ladder to code-writing roles (the runner exports this itself):

```bash
export PONYTAIL_SUBAGENT_MATCHER='implementer|frontend-implementer|backend-implementer|micro-fixer'
```

`PONYTAIL_ENFORCE=0` is the loud escape hatch — the run continues without
the ladder, recorded in state.json and flagged in the reports.

## Notes

- Existing skill folders with the same names are overwritten.
- The 0-to-8 core chain (incl. `0b_intake`, `3a_cross-review`) and optional skills are installed.
- `CLAUDE.md` is not installed as a skill. It is a repo-level pointer file only.
