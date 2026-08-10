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

- Existing skill folders with the same names are overwritten.
- The 0-to-8 core chain and its `cross-review` mechanism are installed, along with the documented optional skills: `bugfixing`, `refactor-dreamer`, and `sonar-cli`.
- `CLAUDE.md` is not installed as a skill. It is a repo-level pointer file only.
