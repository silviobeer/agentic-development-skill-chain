# Repository Instructions

- Keep `AGENTS.md` as the only curated durable-context file.
- Keep `CLAUDE.md` pointer-only; it must reference `AGENTS.md` and must not contain durable rules.
- Keep Codex and Claude skill chains aligned unless tool-specific wording is required.
- Include only the core 0-to-7 chain and explicitly documented optional skills in this repository.
- Run `./scripts/validate.sh` before publishing changes.
