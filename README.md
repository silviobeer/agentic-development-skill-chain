# Agentic Development Skill Chain

An opinionated 0-to-7 skill chain for agentic software development, maintained in parallel for Codex and Claude.

The chain turns a rough product idea into a buildable concept, explores UI shape when needed, writes requirements, creates architecture and implementation plans, executes the work, runs QA, and curates human-readable documentation.

## What Is Included

```text
0_process-guide
1_brainstorming
1b_visual-companion
2_requirements-engineer
2a_frontend-design
2b_ui-mockup
3_architecture
4_writing-plans
5_executing
6_qa
7_documentation
```

Only the core chain is included. Claude-specific experimental or personal skills are intentionally excluded.

## Repository Layout

```text
codex/skills/    Codex version of the chain
claude/skills/   Claude version of the chain
docs/            Human documentation for this repository
scripts/         Install and validation helpers
```

`AGENTS.md` is the only curated durable-context file. `CLAUDE.md` is pointer-only and tells Claude to read `AGENTS.md`.

## Install

Install the Codex skills:

```bash
./scripts/install-codex.sh
```

Install the Claude skills:

```bash
./scripts/install-claude.sh
```

Both scripts copy only the bundled 0-to-7 chain into the default local skill directories.

## Validate

```bash
./scripts/validate.sh
```

The validation script checks that the expected skill folders exist, every skill has `SKILL.md` frontmatter, `CLAUDE.md` stays pointer-only, and stale `CLAUDE.md Candidates` conventions do not reappear.

## Inspirations

This repo was shaped by ideas from:

- [Get Shit Done](https://github.com/majiayu000/claude-skill-registry/tree/main/skills/data/get-shit-done)
- [Superpowers](https://github.com/obra/superpowers)
- [Alex Sprogis](https://www.alexsprogis.de/)

## License

MIT
