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

## Notes

- Existing skill folders with the same names are overwritten.
- Only the 0-to-7 core chain is installed.
- `CLAUDE.md` is not installed as a skill. It is a repo-level pointer file only.
