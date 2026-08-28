# Implementer Subagent Prompt Template

Use this template when dispatching a subagent for a user story. Fill in all bracketed placeholders before dispatching. The subagent should not need to read any files — everything it needs must be included in the prompt.

## Template

```
Task tool:
  description: "Implement [US-N]: [user story short title]"
  prompt: |
    You are implementing a single user story. Your job is to implement all tasks
    for this story using TDD, then run one bounded internal self-review.

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
    [Skip this section in framework runs — the frontend-implementer context bundle
     already injects docs/DESIGN-SYSTEM.md and docs/components.md.
     Outside bundle runs, paste both files here (DESIGN-SYSTEM.md is capped at 80
     lines, so paste it whole; components.md may be trimmed to the relevant entries).
     The subagent MUST reuse registered components — never one-off styled elements.]

    ## Agent Notes (long-term memory)
    [Optionally paste known-relevant sections from `agent.md` in the source folder.
     Regardless of what is pasted, the subagent follows the agent.md READ rule below —
     the paste is a convenience, not a substitute.]

    ## Your Job
    For each task (in order):
    1. Write a failing test (RED)
    2. Run the test — verify it fails for the expected reason
    3. Implement minimal code to make it pass (GREEN)
    4. Run ALL tests — new + existing must pass
    5. Refactor if needed, re-run tests
    6. Commit: `feat(PROJ-<X>-PRD-<Y>): implement [task name]`

    After all tasks:
    7. Run one bounded Inner Ralph self-review covering both:
       - Spec compliance — does the implementation match the task requirements?
       - Code quality — error handling, type safety, test quality, architecture.
    8. Fix confirmed findings once, then re-run targeted tests. Report unresolved
       issues to the main agent; do not start another self-review cycle.
    9. Report back.

    ## Rules
    - No production code without a failing test first
    - Never claim a test passes without running it and reading the output
    - A test that depends on external state (provider rate budget, suite order, or time) must establish that state itself or explicitly assert it. “Nothing happened” needs a positive control: prove the valid session/input/path would work, and do not let a polling matcher pass before observing the intended transition.
    - Minimal implementation — YAGNI, do not build beyond what the tasks ask
    - If stuck after 3 attempts, escalate to main agent instead of guessing
    - Do NOT verify acceptance criteria — that is the main agent's job
    - UI: Use existing components from `@/components/ui/` — never create one-off styled elements
    - UI: Never hardcode hex colors or arbitrary sizes — use the token classes named in `docs/DESIGN-SYSTEM.md`
    - UI: Follow the radius, spacing, and pattern rules in `docs/DESIGN-SYSTEM.md`
    - UI: Use project-specific shared components (see the `docs/components.md` registry)
    - UI: If no registered component fits, do NOT style a one-off — escalate to the main agent
      so the design system gets extended (variant first, new component only if needed)

    ## agent.md Protocol (long-term local memory)
    READ (mandatory): before your FIRST edit in any folder, read that folder's
    `agent.md` and the nearest feature-level ancestor's — max 2 files, never
    every parent up to the repo root. Entries are hints, not rules: verify
    before you rely on them. Rules come from docs/ and AGENTS.md.

    WRITE: the moment a learning occurs (a wall + workaround, a dead end, a
    pattern that worked) — immediately, not at wrap-up — at the DEEPEST
    applicable level:
    - applies only to one folder    -> that folder's `agent.md`
    - applies to the whole feature  -> the feature folder's `agent.md`
    - applies project-wide          -> `## AGENTS.md Candidates` in progress.md
    - it is a defect                -> ledger (`node scripts/ledger.mjs add`), never agent.md
    Render entries with `templates/agent-md-entry.md.tmpl`: dated + commit SHA,
    under exactly one of `## Gotchas` / `## Patterns That Work Well` /
    `## Dead Ends`. Max 100 lines per agent.md (curation-caps.sh gates P7) —
    beyond that, curate first, then append. Include every new entry in your
    report so the main agent can update progress.md.

    ## Components — reuse before create (UI tasks only, HARD RULE)
    Before creating any component file in `src/components/` or `src/features/*/components/`:
    1. `grep -rn "export function <Name>" src/components/ src/features/*/components/ 2>/dev/null` — check for exact matches
    2. `grep -rn "export function.*<Semantic>" src/components/` — check for semantically similar (e.g. `Badge`, `Chip`, `Tag`)
    3. Read `docs/components.md` registry end-to-end
    4. If anything comparable exists → **reuse or extend**, don't create
    5. If truly new → write a doc block above the export, in the SAME commit as the
       component file. This block IS the registry entry — there is no second list:
         /** Actions. Not for navigation — use Link.
          *  @variants primary|ghost  @sizes sm|md  @states hover|disabled */
         export function Button(…)
    6. Regenerate: `node scripts/gen-component-registry.mjs` and commit `docs/components.md`
    7. If a `/dev/components` showcase route exists → add the new component there too, with
       its variants and states. QA checks that every registered component renders.
    A component without a doc block, or a stale `docs/components.md`, fails the wave gate.

    ## agent.md Criteria (strict)
    Only add an `agent.md` entry if ALL three hold:
    1. **Non-obvious:** Not derivable from reading the code or docs.
    2. **Durable:** Future agents working here would trip over it too — not a one-off state of this task.
    3. **Compact:** ≤ 2 lines of entry text.
    Skip the entry if any criterion fails — noise in `agent.md` poisons future agents. One-off idiosyncrasies belong in the code's own comments, not here. P7 curation later keeps what is confirmed, deletes what is outdated, and promotes project-wide entries to AGENTS.md candidates.

    ## Report Format
    - US implemented: [US-N title]
    - Tasks completed: [list]
    - Tests run: [test names, commands, actual output summary]
    - Files changed: [paths]
    - Inner Ralph self-review: [clean | fixes applied | unresolved issues]
    - Walls hit & workarounds: [list or "none" — already written to agent.md]
    - Open concerns or escalations: [list or "none"]
```

## Usage Notes

- Paste the full task text. The subagent must not read the spec or plan files.
- Include enough prior-wave context so the subagent understands what already exists.
- After every wave worker reports back, the main agent runs the wave-scoped AC verification pass — not the subagent.
- For parallel waves: dispatch all US subagents in the same wave simultaneously using multiple Task tool calls in one message.
