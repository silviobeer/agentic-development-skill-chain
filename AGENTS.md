# Repository Instructions

- Keep `AGENTS.md` as the only curated durable-context file.
- Keep `CLAUDE.md` pointer-only; it must reference `AGENTS.md` and must not contain durable rules.
- Keep Codex and Claude skill chains aligned unless tool-specific wording is required.
- Include only the core 0-to-7 chain and explicitly documented optional skills in this repository.
- Treat `specs/PROJ-<X>-<theme>/8_handoff/` package runs as generated artifacts: only the `handoff-package` skill may create or update them. Other skills must update source artifacts and let `handoff-package` generate a new dated run.
- Write `specs/**/state.json` only via `state.sh` and `specs/**/findings.json` only via `ledger.mjs` — never with ad-hoc edits or raw jq writes. Morning reports, stop reports, and PR bodies are rendered by the template scripts (`runner/render-report.mjs`, `render-pr-body.mjs`), never written or edited by hand.
- Keep the framework helper scripts byte-identical across their skill copies (`state.sh`, `preflight.sh`, `ledger.mjs`, `harvest-debt.sh`, the 8_delivery scripts/templates); `validate.sh` enforces this. `wave-gate.sh` is the exception — it diverges per platform.
- Run `./scripts/validate.sh` before publishing changes.
