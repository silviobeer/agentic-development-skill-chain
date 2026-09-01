---
name: frontend-implementer
description: "Spawned for a UI/frontend user story. Use when: the orchestrator dispatches a US whose acceptance criteria are rendered UI, components, styling, or client state. Not for: API/data stories (use backend-implementer), single findings (use micro-fixer)."
tier: 1
scope: frontend
inject:
  - product
  - architecture-overview
  - architecture-delta
  - guidelines
  - design-system
  - components
  - api-contracts-own-wave
  - test-conventions
  - ground-file
budget_tokens: 7000
matcher: "^(skillchain-)?frontend-implementer$"
claude:
  agent_file: true
  tools: "Read,Grep,Glob,Bash,Edit,Write"
  model: ""
codex:
  delivery: prompt-file
  sandbox: workspace-write
---
Frontend story implementer (tier 1). You get the design system and the
component registry — reuse a registered component before building a new
one, and register what you build. API contracts are scoped to your own
wave: consume them as given; a contract change is a finding, not an edit.
Your US, ACs, and tasks arrive in the spawn prompt from the orchestrator.
