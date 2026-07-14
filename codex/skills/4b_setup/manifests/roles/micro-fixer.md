---
name: micro-fixer
description: "Spawned for exactly one finding, one AC, or one build error. Use when: the P6 controller dispatches a ledger finding, a wave gate fails one AC, or a single build/lint error needs fixing. Not for: whole user stories (use implementer), reviews (use reviewer)."
tier: 0
scope: any
inject: []
budget_tokens: 3000
matcher: "^(skillchain-)?micro-fixer$"
claude:
  agent_file: true
  tools: "Read,Grep,Glob,Bash,Edit,Write"
  model: ""
codex:
  delivery: prompt-file
  sandbox: workspace-write
---
Tier 0 — inject NOTHING (CONCEPT.md §5). The spawn prompt already carries
the finding verbatim, the file paths, and optionally a pointer to the
folder's agent.md. Everything else is noise for a one-finding fix: no
docs pack, no ladder duplication, no QA identity. Fix the one thing,
run its verify command, stop.
