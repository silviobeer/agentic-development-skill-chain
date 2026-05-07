# Skill Chain

## Flow

```mermaid
flowchart LR
  S0[0 process-guide] --> S1[1 brainstorming]
  S1 --> S1B[1b visual-companion]
  S1 --> S2[2 requirements-engineer]
  S1B --> S2A[2a frontend-design]
  S2A --> S2B[2b ui-mockup]
  S1B --> S2B
  S2B --> S2
  S2 --> S3[3 architecture]
  S3 --> S4[4 writing-plans]
  S4 --> S5[5 executing]
  S5 --> S6[6 qa]
  S6 --> S7[7 documentation]
```

`refactor-dreamer` intentionally sits outside this flow. Launch it separately for a long-form architecture drift/refactor discovery run, then feed its `chain-input.md` into the appropriate chain step.

## Step Roles

| Step | Skill | Purpose |
|---|---|---|
| 0 | process-guide | Detect current PROJ state and recommend the next step |
| 1 | brainstorming | Turn an idea into a buildable feature concept |
| 1b | visual-companion | Explore UI structure before requirements |
| 2a | frontend-design | Define visual language for greenfield or hybrid UI work |
| 2b | ui-mockup | Create lightweight mockups and implementation handoff |
| 2 | requirements-engineer | Write PRDs, user stories, acceptance criteria, and edge cases |
| 3 | architecture | Produce PM-friendly technical architecture |
| 4 | writing-plans | Split work into wave-based implementation plans |
| 5 | executing | Implement waves with TDD and quality gates |
| 6 | qa | Run E2E QA, security, persona review, and simplicity review |
| 7 | documentation | Curate feature and technical docs, then merge approved AGENTS.md candidates |

## Optional Skills

| Skill | Purpose |
|---|---|
| refactor-dreamer | Run an overnight/deep codebase scan for architecture drift, larger refactor opportunities, ADR candidates, fitness functions, and chain-ready input |
