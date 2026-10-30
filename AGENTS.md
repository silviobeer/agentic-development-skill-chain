# Repository Instructions

- Keep `AGENTS.md` as the only curated durable-context file.
- Keep `CLAUDE.md` pointer-only; it must reference `AGENTS.md` and must not contain durable rules.
- Keep Codex and Claude skill chains aligned unless tool-specific wording is required.
- Include only the core 0-to-8 chain and explicitly documented optional skills in this repository.
- Treat `specs/PROJ-<X>-<theme>/2b_handoff/` package runs as generated artifacts: only the `handoff-package` skill may create or update them. Other skills must update source artifacts and let `handoff-package` generate a new dated run.
- Write `specs/**/state.json` only via `state.sh` and `specs/**/findings.json` only via `findings.mjs` — never with ad-hoc edits or raw jq writes. Morning reports, stop reports, and PR bodies are rendered by the template scripts (`render.mjs`), never written or edited by hand.
- Keep the framework helper scripts byte-identical across their skill copies (`chain`, `chain-status.mjs`, `state.sh`, `preflight.sh`, `env-local.sh`, `compat.sh`, `validate-prds.mjs`, `validate-architecture.mjs`, `validate-wave-plan.mjs`, `compile-context.mjs`, `story-slice.mjs`, `document-parser.mjs`, `architecture-parser.mjs`, `resolve-inputs.mjs`, `integration-status.mjs`, `render.mjs`, `worktree.sh`, the role manifests, `curation.sh`, the cross-review scripts/template, `agent-md-entry.md.tmpl`, `findings.mjs`, `findings-store.mjs`, `runner/prompts/p6-controller.md` (also as `5_executing/references/p6-controller.md`), `in-session-driver.md`, `wave-gate.sh`, `quality.mjs`, the 8_delivery scripts/templates); `validate.sh` enforces this.
- `merge-project-settings.sh` and `references/project-settings-template.json` are Claude-only by design (they edit `.claude/settings.json`); do not copy them into the Codex tree for symmetry. The `wave-gate-enforcer.js` hook is an optional personal Claude hook outside this repo; no skill may present it as shipped or required.
- When a change needs a newer tool (Node, bash, git, jq, Claude Code, Codex), raise its `REQ_*` minimum in `scripts/requirements.sh`, the single source for `install.sh` and `check-setup.sh`. Download pins (`NVM_VERSION`, `SONAR_SCANNER_VERSION`) live in the same file, under their own heading.
- Run `./scripts/validate.sh` before publishing changes.

- Through Step 4, producing skills hand off via a copyable prompt to a new user-started session; checks and automatic cross-review finish in the current skill session. Do not replace this boundary with `/compact` or auto-invoke the next producing skill.

- From Requirements Engineer (Step 2) onward, all newly authored artifacts are English; user conversation may remain in the user's language. Preserve identifiers, verbatim evidence and intended product localization.
