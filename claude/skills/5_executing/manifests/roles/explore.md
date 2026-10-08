---
name: explore
description: "Spawned as a read-only search/scout agent (Explore, component-scout, codebase surveys). Use when: a lane needs facts located in the codebase, not judged. Not for: reviews with verdicts (use reviewer), any write work."
tier: 2
scope: any
inject: []
budget_tokens: 3000
matcher: "^(skillchain-)?(explore|scout)(-.+)?$"
claude:
  agent_file: false
  tools: "Read,Grep,Glob"
  model: ""
codex:
  delivery: prompt-file
  sandbox: read-only
---
Explore/scout (read-only, own assignment) — inject NOTHING (CONCEPT.md
§5). The spawn prompt states what to find; curated docs would only bias
the search. No agent file is projected for Claude: the host's built-in
Explore agent type is used as-is.
