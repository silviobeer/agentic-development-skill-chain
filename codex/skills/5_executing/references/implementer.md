# Implementer Subagent Prompt Template

Use this template when dispatching a subagent for a user story. Fill in all bracketed placeholders before dispatching. The subagent should not need to read any files — everything it needs must be included in the prompt.

## Template

```
Task tool:
  description: "Implement [US-N]: [user story short title]"
  prompt: |
    You are implementing a single user story. Your job is to implement all tasks
    for this story using TDD, then run a 2-stage internal review.

    ## User Story
    [FULL TEXT of the user story — Given/When/Then]

    ## Acceptance Criteria
    [List of ACs for this story — verbatim from the plan]
    Note: You do NOT verify ACs yourself. The main agent does that after you report back.

    ## Tasks
    [FULL TEXT of all tasks under this US — paste them here with TDD steps]

    ## Codebase Context
    [Relevant file paths, existing patterns, conventions, tech stack notes]
    [What was implemented in previous waves that this US builds on]

    ## UI Design System (include for any US that touches UI)
    [Paste relevant sections from the project's design-system.md reference
     (check `.codex/skills/references/design-system.md` in the project, or
     `~/.codex/skills/references/design-system.md` globally).
     At minimum include: Do/Don't rules, component catalog, and typography scale.
     The subagent MUST use existing components — never create one-off styled elements.]

    ## Agent Notes (long-term memory)
    [Paste relevant sections from `agent.md` in the source folder — gotchas, dead ends,
     known workarounds. Omit if no agent.md exists yet.]

    ## Your Job
    For each task (in order):
    1. Write a failing test (RED)
    2. Run the test — verify it fails for the expected reason
    3. Implement minimal code to make it pass (GREEN)
    4. Run ALL tests — new + existing must pass
    5. Refactor if needed, re-run tests
    6. Commit: `feat(PROJ-<X>-PRD-<Y>): implement [task name]`

    After all tasks:
    7. Run 2-stage internal review:
       - Stage 1: Spec compliance — does the implementation match the task requirements?
         Read `references/spec-reviewer.md` for the review checklist.
       - Stage 2: Code quality — error handling, type safety, test quality, architecture.
         Read `references/code-reviewer.md` for the review checklist.
    8. Fix any review findings (critical first), re-run tests, re-review until clean.
    9. Report back.

    ## Rules
    - No production code without a failing test first
    - Never claim a test passes without running it and reading the output
    - Minimal implementation — YAGNI, do not build beyond what the tasks ask
    - If stuck after 3 attempts, escalate to main agent instead of guessing
    - Do NOT verify acceptance criteria — that is the main agent's job
    - UI: Use existing components from `@/components/ui/` — never create one-off styled elements
    - UI: Never hardcode hex colors — use Tailwind semantic classes (bg-primary, text-muted-foreground)
    - UI: Follow border-radius, spacing, and component rules from the design system reference
    - UI: Use project-specific shared components (see design-system.md Custom Components table)

    ## Walls & Workarounds
    If you hit a wall and find a workaround, document it immediately:
    - Write it to `agent.md` in the feature source folder
    - Include it in your report so the main agent can update progress.md
    Format: what failed, why, what you did instead.

    ## Components — reuse before create (UI tasks only, HARD RULE)
    Before creating any component file in `src/components/` or `src/features/*/components/`:
    1. `grep -rn "export function <Name>" src/components/ src/features/*/components/ 2>/dev/null` — check for exact matches
    2. `grep -rn "export function.*<Semantic>" src/components/` — check for semantically similar (e.g. `Badge`, `Chip`, `Tag`)
    3. Read `docs/components.md` registry end-to-end
    4. If anything comparable exists → **reuse or extend**, don't create
    5. If truly new → **add entry to `docs/components.md` in the same commit** as the component file, with 1-line purpose + props summary
    The `component-registry-check.js` PreToolUse hook enforces step 5 mechanically.

    ## agent.md Criteria (strict)
    Only add an `agent.md` entry if ALL three hold:
    1. **Non-obvious:** Not derivable from reading the code or docs.
    2. **Project-wide:** Relevant outside this one feature (future devs in other modules would trip over it too).
    3. **Compact:** ≤ 2 lines.
    Skip the entry if any criterion fails — noise in `agent.md` poisons future agents. Feature-specific idiosyncrasies belong in the code's own comments, not here. Skill 7 (documentation) later harvests `agent.md` entries into `docs/TECHNICAL.md`.

    ## Report Format
    - US implemented: [US-N title]
    - Tasks completed: [list]
    - Tests run: [test names, commands, actual output summary]
    - Files changed: [paths]
    - Inner Ralph iterations: [N — how many review fix cycles were needed]
    - Walls hit & workarounds: [list or "none" — already written to agent.md]
    - Open concerns or escalations: [list or "none"]
```

## Usage Notes

- Paste the full task text. The subagent must not read the spec or plan files.
- Include enough prior-wave context so the subagent understands what already exists.
- After the subagent reports back, the main agent runs the AC verification loop — not the subagent.
- For parallel waves: dispatch all US subagents in the same wave simultaneously using multiple Task tool calls in one message.
