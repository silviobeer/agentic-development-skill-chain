---
name: executing
description: "Execute implementation plans user-story by user-story using agent teams. Spawns teammates per US in dependency order, with Ralph loops as the quality gate. Runs a Quality Gate (code review + SonarCloud) and QA per PROJ-X before moving to the next. Use when: (1) an implementation plan exists and is ready for execution, (2) feature tasks need to be implemented with TDD. Not for: planning, architecture, or requirements."
---

# Executing

Orchestrate implementation by creating an agent team and spawning teammates per user story. The lead (main agent) stays in the loop: after each US is implemented, it runs an outer Ralph loop — checking every acceptance criterion deterministically until all pass.

**Agent Teams vs Subagents:** This skill uses agent teams so that teammates can communicate with each other during parallel waves. When one teammate discovers a gotcha, it broadcasts to all others immediately — no waiting for the wave to finish. For sequential single-US waves, a regular subagent is fine.

**One PROJ at a time:** The executing loop runs per PROJ. Each PROJ has multiple wave-plan files (`PROJ-<X>-wave-1-plan.md`, `PROJ-<X>-wave-2-plan.md`, …) that are read in order. A single `7_progress/PROJ-<X>-progress.md` tracks all waves. When the user provides multiple PROJ plans, execute each PROJ fully (all waves → Quality Gate → QA) before starting the next.

**Decomposed PROJs:** If the plan references sibling PROJs, treat them as dependencies or context only. Do not implement sibling scope from the current PROJ's waves. If a wave depends on an incomplete sibling PROJ, stop before that wave and report the blocker. Shared design-language files from sibling PROJs may be consumed, but they do not authorize building sibling workflows.

## Context economy — always delegate to subagents

The orchestrator (main agent) must stay lean so it survives the full PROJ → QA → docs chain without a mid-run compact crash. **Default: delegate everything to subagents; main agent only coordinates.**

- **US implementation:** always spawned (`implementer` / `backend-implementer` / `frontend-implementer`). Never write code inline.
- **Ralph AC loops:** drive from subagents; main agent only collects verdicts.
- **PROJ-end Ken review:** spawned in Skill 6, not read inline. Ken no longer runs per wave — only once against the assembled PROJ.
- **Quality Gate (Step 9):** `code-reviewer-gate` + `sonar-scanner-gate` run as parallel subagents, not inline review by the orchestrator.
- **Fix-spawns:** every Critical/High finding is fixed by a spawned subagent, clustered by file.
- **Even single-file edits:** if the edit needs to read 5+ files first, spawn — don't pull them into the orchestrator context.

Subagents return a ≤ 300-token summary; raw diffs/logs stay in their context and die with them. The orchestrator keeps only IDs, verdicts, and next-step pointers. If the main agent has to read more than ~3 source files directly for a decision, it's the wrong tool — spawn an `Explore` or domain agent instead.

**Run in background by default.** Spawn all subagents with `run_in_background: true` unless the orchestrator genuinely cannot proceed without the result. Background spawns let the orchestrator dispatch the next wave of work immediately and get notified on completion — parallel fan-out without blocking. Foreground is the exception, not the norm. Dependencies like `implementer → Ralph → Build → Gate` still run sequentially (the orchestrator awaits each stage), but within a stage every independent spawn goes to background in a single parallel batch.

---

## FIRST ACTION (before reading any plan)

<HARD-GATE>
Before doing ANYTHING else — before reading plans, before spawning any agent:
0. Run `/compact` to flush prior conversation context. Steps 1–4 leave large artifacts in the context window that are no longer needed — the PRDs, architecture and wave plans are on disk. Reclaim that space now before the most context-intensive step begins.
1. **Permission preflight — verify Claude Code was started with `--dangerously-skip-permissions`**:
   - The `defaultMode: "bypassPermissions"` setting in `.claude/settings.json` covers most cases but some tools (MCP, certain Bash patterns) still prompt. For true zero-prompt autonomous execution, Claude Code MUST be launched with the CLI flag `claude --dangerously-skip-permissions`.
   - Detection: if a Bash/Write/Edit tool call prompts the user during this skill, the flag is missing. STOP and tell the user: "Start Claude Code with `claude --dangerously-skip-permissions` for uninterrupted execution. Current session has permission prompts active."
   - **Fallback (belt-and-braces) — project permissions merge**: still run `bash scripts/merge-project-settings.sh` once per project so the allowlist + `defaultMode: bypassPermissions` are in place. If the merge script is missing, copy it from `~/.claude/skills/5_executing/scripts/merge-project-settings.sh`, `chmod +x`, commit. After merge, commit `.claude/settings.json` with `chore: enable Skill 5/6/7 execution permissions`. The merge is authoritative even when users forget the CLI flag.
   - In autonomous mode the merge runs silently; interactively, show a summary ("added N allow / M deny rules") before commit.
1b. **CodeRabbit config preflight** (wave reviews depend on this):
   - If `.coderabbit.yaml` or `.coderabbit.yml` is missing at repo root, copy `~/.claude/skills/5_executing/references/coderabbit-template.yaml` to `.coderabbit.yaml` and commit it. Adjust `path_filters` and `tools.biome.enabled` for the project (remove `biome` block if the project uses ESLint instead).
   - If the config exists, verify it has: `reviews.profile` set (ideally `chill`), `reviews.path_filters` excluding `node_modules`/`dist`/`build`/lockfiles, and no overly-broad `path_instructions` that would swamp the per-wave review. If violations — propose a patch, don't silently rewrite; commit only with user-visible diff.
   - Rationale: without a focused config, CodeRabbit's per-wave review generates hundreds of Low/Medium findings that slow the gate and bury Critical/High signal.

2. **MCP preflight check** (fail fast):
   - If `package.json` contains `@supabase/*` OR `supabase/` folder exists → verify `mcp__claude_ai_Supabase__*` tools are in the available tool list. Missing → STOP, tell user to reconnect Supabase MCP.
   - If any wave in `wave-gate-config.json` has non-empty `frontend_routes` → verify Playwright or active agent-browser/browser automation tools are available. Missing → STOP, tell user: QA in Skill 6 will fail without browser automation. Reconnect or configure browser tooling before continuing.
   - `agent-browser`, `coderabbit`, `jq` CLIs: verify via `command -v`. Missing → STOP.
3. Record BASE_SHA: `git rev-parse HEAD`
4. Create `specs/PROJ-<X>-<thema>/7_progress/PROJ-<X>-progress.md` using the template below
5. Store BASE_SHA in progress.md

This file is your single source of truth for the whole PROJ. Update it after EVERY action.
If progress.md does not exist, you have skipped this step — STOP and create it now.
</HARD-GATE>

---

## Wave Completion Gate

<HARD-GATE>
Before spawning ANY teammate for a new wave N+1, you MUST first fill the Post-Wave-Notes, then run the Wave Gate script — it MUST exit 0.

**Pre-Gate step:** For each US in `6_plan/PROJ-<X>-wave-<N>-plan.md`, fill the `### Post-Wave Notes` placeholder block with the Skill-4-reserved sub-items:
- `Deviations from plan:` — what ended up different from the task description? Write `—` if none.
- `Surprising gotchas:` — anything a future dev/agent should know? Write `—` if none.
- `New dependencies:` — new packages/libs introduced by this US? Write `—` if none.

Source the content from `progress.md` + commit messages for the wave's SHA range. Keep each sub-item to one line. Skill 7 reads this verbatim; empty entries (`—`) are fine and explicit.

```bash
bash scripts/wave-gate.sh <N> <PROJ-X> <thema>
```

Exit code ≠ 0 → STOP. Fix the failing check, re-run the script until green. Only then spawn the next wave's teammates.

The script validates:
1. **Ralph ACs** — every `ac_commands` entry from `6_plan/wave-gate-config.json` for wave N exits 0
2. **Build** — `build_cmd` from config exits 0
3. **CodeRabbit** — 0 Critical/High findings against wave start SHA
4. **Smoke Test** — `agent-browser` passes on every `frontend_routes` entry (skipped if empty)

On success the script appends a `### Wave N Gate — PASSED` block with timestamp to `progress.md`. This is the canonical proof that the wave is done — no manual checkbox editing.

**If the wave-gate.sh script is missing from the project:** copy the template from `~/.claude/skills/5_executing/scripts/wave-gate.sh` to `scripts/wave-gate.sh`, `chmod +x` it, commit it before running the first wave.

**If jq, coderabbit, or agent-browser are missing:** the script prints a clear error and exits non-zero. Install them, do not work around the gate.

**Belt-and-braces enforcement:** A global PreToolUse hook (`~/.claude/hooks/wave-gate-enforcer.js`) inspects every `Agent` spawn. When `subagent_type` is `implementer` / `backend-implementer` / `frontend-implementer` and the prompt mentions Wave N with N > 1, it refuses the spawn unless `### Wave N-1 Gate — PASSED` exists in `7_progress/PROJ-<X>-progress.md`. The script is the primary gate; the hook is the fail-safe so the main agent cannot accidentally skip it.
</HARD-GATE>

---

## Memory Files

Two files are maintained throughout execution:

### `progress.md` (short-term memory)
Created at the start of execution, lives in `specs/` alongside the plan.
Tracks granular build state — task completion, test status, AC verification, and blockers.
Updated after every task, after every Ralph loop iteration, and whenever a blocker occurs.

```markdown
# PROJ-X Progress

## Status: [in progress | blocked | complete]
## Current Wave: [N]
## BASE_SHA: [commit hash before first change]

---

## US-1: [title] — [pending | in progress | complete]

### Tasks
| Task | Tests Written | Tests Passing | Done |
|------|:---:|:---:|:---:|
| 1.1 [name] | ✗ | — | ✗ |
| 1.2 [name] | ✓ | ✓ | ✓ |
| 1.3 [name] | ✓ | ✗ | ✗ |

### Acceptance Criteria
| AC | Text | Verified |
|----|------|:---:|
| AC-1 | [verbatim from spec] | ✓ |
| AC-2 | [verbatim from spec] | ✗ |
| AC-3 | [verbatim from spec] | — |

### Ralph Loop
- Iterations: 1
- AC-2 pass 1: FAIL — [exact failure reason] → fix subagent spawned
- Commit: `feat(PROJ-<X>-PRD-<Y>): implement US-1 [name]`

---

## US-2: [title] — pending
*(blocked by US-1)*

---

## Quality Gate — PROJ-X

### Code Review
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| P0 Critical | 0 | 0 | 0 |
| P1 High | 0 | 0 | 0 |
| P2 Medium | 0 | 0 | 0 |
| P3 Low | 0 | 0 | 0 |

### SonarCloud
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| Critical/Major | 0 | 0 | 0 |
| Minor | 0 | 0 | 0 |
| Info | 0 | 0 | 0 |

### Fixed Issues
- [severity]: `file:line` — [issue] → fixed in [commit]

### Deferred (user decision)
- [severity]: `file:line` — [issue]

---

## QA Results

- Bugs found: N (Critical: N, High: N, Medium: N, Low: N)
- Fixed: N
- Deferred: N

---

## Open Blockers
- US-7: [exact reason] — escalated to user [timestamp]
```

**Update rules:**
- Subagent updates task rows after each TDD cycle (tests written → tests passing → done)
- Main agent updates AC rows after each Ralph loop iteration
- `—` means not yet attempted; `✗` means attempted and failing; `✓` means passing
- Ralph Loop section appended after each iteration with verbatim failure reason

### `agent.md` (long-term memory)
Lives in the feature's **source folder** (e.g., `src/features/deliveries/agent.md`).
Written when any agent hits a wall and finds a workaround — or discovers something a future developer must know.
Written like notes to a developer who has never seen this code.

```markdown
# Agent Notes — [Feature Name]

## Gotchas

### Supabase RLS blocks server actions without explicit role claim
Discovered during US-4 (activate delivery). Server actions run as `anon` unless
`set role authenticated` is called explicitly. Workaround: call `supabase.auth.getUser()`
at the top of every mutating server action before any DB write.

### Zod refinements don't run on optional fields when undefined
If a field is optional and undefined, `.refine()` is skipped entirely.
Use `.optional().refine()` vs `.refine()` on the base type — different behavior.

## Patterns That Work Well
...

## Dead Ends (don't try these again)
...
```

Write to `agent.md` immediately when a learning occurs — not at the end. Future subagents in the same session read it at the start.

---

## Input

Read the following before starting each PROJ:

**All PRDs** — `specs/PROJ-<X>-<thema>/3_PRDs/*.md`. These are the authoritative requirements source. Used by the outer Ralph loop to verify ACs. If plan and PRD disagree on AC text, the PRD wins.

**Architecture** — `specs/PROJ-<X>-<thema>/6_plan/PROJ-<X>-architecture.md`. Cross-PRD tech design.

**Wave plans** — `specs/PROJ-<X>-<thema>/6_plan/PROJ-<X>-wave-<N>-plan.md` (in numeric order). Each wave plan lists:
- The user stories in that wave (may span multiple PRDs)
- Tasks per US with TDD cycle descriptions and file paths
- For UI tasks, UI Implementation Notes and UI handoff constraints propagated from `5_mockups/implementation-handoff.md`

**UI implementation handoff** — for UI PROJs, read `specs/PROJ-<X>-<thema>/5_mockups/implementation-handoff.md` before starting implementation. It is the compact source for project mode, component reuse, new component candidates, design tokens, interaction contract, implementation tolerance, and demo-only mockup exclusions.

The PRDs define WHAT success means. The wave plans define HOW to get there. The UI handoff defines how to preserve the approved interface shape without treating HTML mockups as pixel-perfect production specs.

**When multiple PROJ plans are provided:** Execute one PROJ fully (all waves → Quality Gate → QA) before starting the next. Each PROJ has its own `7_progress/PROJ-<X>-progress.md`.

---

## Per-PROJ-X Execution Loop

For each PROJ-X plan (in order):

```
0. Record BASE_SHA (git rev-parse HEAD)
1. Create specs/PROJ-<X>-<thema>/7_progress/PROJ-<X>-progress.md
2. Execute waves (Steps 1–5 below)
3. Build check after each wave (Step 5)
4. CodeRabbit wave review after each wave (Step 7)
5. Mark wave complete (Step 8)
6. Quality Gate after all waves (Step 9)
7. QA + Fix Loop (Step 10)
8. Mark PROJ-X complete
→ Next PROJ-X
```

After ALL PROJ-X plans complete: Final Summary Report (Step 9).

---

## Orchestration (per PROJ-X)

### 0. Record BASE_SHA

Before any implementation changes, record the current commit:
```bash
git rev-parse HEAD
```
Store this in `progress.md` as `BASE_SHA`. It is used later by the Quality Gate to diff only this feature's changes.

### 1. Read the dependency map

Extract waves from the plan's dependency table:

```
Wave 1: US-1                    → 1 teammate
Wave 2: US-2, US-7 (parallel)   → 2 teammates simultaneously + integration-guard
Wave 3: US-3                    → 1 teammate
...
```

### 2. Before each wave: read `agent.md`

If `agent.md` exists in the source folder, read it before spawning teammates.
Include relevant sections in the teammate prompt so they don't repeat known dead ends.

### 2a. Mark wave start with a git tag

<HARD-GATE>
Before spawning any teammate for wave N, tag the current HEAD as the wave base. `wave-gate.sh` resolves this tag to scope the CodeRabbit diff. Without `WAVE_BASE_SHA` or this tag, the gate fails hard. This prevents accidentally reviewing broad branch history.
</HARD-GATE>

```bash
git tag "wave-${WAVE}-start-PROJ-${PROJ}"
```

One tag per (wave, PROJ) pair. Tags are local-only; do not push. If neither `WAVE_BASE_SHA` nor `wave-${WAVE}-start-PROJ-${PROJ}` exists, `wave-gate.sh` fails hard. There is no `HEAD~20`, commit-message, or root-commit fallback. If the tag already exists from a re-run, delete and re-create: `git tag -d "wave-${WAVE}-start-PROJ-${PROJ}"`.

### 3. Create team and spawn teammates for the wave

**For waves with 2+ parallel user stories:** Create an agent team. The lead (you) coordinates.

**Choose the right implementer type per US:**
- US touches only UI (components, pages, styling) → `frontend-implementer`
- US touches only server-side (API, DB, server actions) → `backend-implementer`
- US is full-stack (both UI and server logic) → `implementer` (generic)

**Choose the right model per US (from the wave plan's `Complexity` column):**
Read the `Complexity` column in the wave plan's "User Stories in this Wave" table. Pass the value as the `model` parameter on the `Agent` spawn so the teammate runs on the right brain for the job.
- `sonnet` → `model: "sonnet"` (default for standard US)
- `opus` → `model: "opus"` (architecture-sensitive: state machines, concurrency, cross-feature contracts, migrations, auth/session, money, crypto)

Haiku is deliberately not in the menu — US-level work loses too much fidelity on it. If the wave plan is missing the `Complexity` column (older plan format), default to `sonnet` and log a one-line note in `7_progress/PROJ-<X>-progress.md` so the planner can retrofit it.

```
Create an agent team for Wave N of PROJ-X.

Spawn teammates:
- "us-2" using the frontend-implementer agent type, model: "sonnet": [US-2 prompt with full context]
- "us-7" using the backend-implementer agent type, model: "opus": [US-7 prompt with full context — this one touches auth/session]
- "guard" using the integration-guard agent type: Monitor us-2 and us-7 for file conflicts

Require plan approval for each implementer before they make changes.
```

**For waves with a single user story:** Use a regular subagent (no team overhead needed). Pick the matching implementer type based on the US scope.

Pass to each teammate (via `references/implementer.md` template):
- Full user story (Given/When/Then)
- Its acceptance criteria
- Its task list with TDD steps
- Codebase context + conventions
- What previous waves implemented
- Relevant sections from `agent.md`
- **If the US touches UI:** include the relevant `UI Implementation Notes` from the wave plan and the matching sections from `5_mockups/implementation-handoff.md`:
  - Project mode (`greenfield`, `brownfield`, `hybrid`)
  - Mockup file reference and selected UI direction
  - Existing components/tokens to reuse
  - Approved new component candidates
  - Required interaction contract and responsive behavior
  - Implementation tolerance and demo-only exclusions
- **If the US touches UI:** Look for a design system reference file (check `.claude/skills/references/design-system.md` in the project first, then `~/.claude/skills/references/design-system.md` globally). Include Do/Don't rules, component catalog, and typography. The teammate must use existing components — never one-off styled elements.
- **If the US touches Tailwind CSS styling:** Include the contents of `~/.claude/skills/tailwind-css/SKILL.md`. Pass the relevant sections (responsive patterns, dark mode, class organisation, component patterns) so the teammate uses consistent utility classes and avoids conflicts.
- **If the US involves Next.js App Router:** Include the contents of `~/.claude/skills/nextjs-app-router-patterns/SKILL.md`. Pass the relevant sections (Server vs. Client Components, data fetching, routing, caching) so the teammate follows App Router conventions and avoids common pitfalls (e.g. accidentally marking a Server Component as `'use client'`).

**Integration Guard:** For parallel waves, the `integration-guard` teammate monitors file ownership and alerts implementers if they touch overlapping files. This prevents merge conflicts and duplicated utilities.

**UI implementation rule:** Existing React components and design tokens take precedence over exact HTML mockup CSS. Preserve the selected layout direction and interaction contract; do not replace a sidepanel with a modal, a wizard with a single page, or a brownfield component with a one-off styled element unless the user explicitly approved that change.

Wait for all teammates in the wave to complete before running Ralph. Clean up the team after each wave.

### 4. Outer Ralph loop (AC verification per US)

<HARD-GATE>
After EVERY teammate reports back → IMMEDIATELY run Ralph.
This is not optional. This is not "later". This is not "after I commit".
The NEXT thing you do after a teammate completes is verify ACs with actual commands.
Do NOT commit, do NOT proceed to the next wave, do NOT spawn new teammates until Ralph passes.
</HARD-GATE>

After subagents report back, the main agent runs a Ralph loop for each US:

```
RALPH_CAP = 3
iter = 0
while iter < RALPH_CAP and not all ACs pass:
  iter += 1
  for each AC:
    run the deterministic check (test command or direct behavior verification)
    if fail:
      collect exact failure output (test result, error, stack trace)
      spawn fix teammate with: failing AC + verbatim failure output + previous attempts
      update progress.md with iteration details
  re-check all ACs

if iter == RALPH_CAP and not all ACs pass:
  log a "Ralph cap hit" warning in progress.md with the failing ACs + last error
  CONTINUE to next step — do NOT halt, do NOT escalate to user mid-run
```

**Rules for the Ralph loop:**
- Checks must be **deterministic** — run actual test commands, read actual output. No subjective judgment ("this looks like it works").
- Failure output is passed **verbatim** to the fix subagent — not summarized, not interpreted.
- The loop exits when every AC passes OR when the iteration cap is reached.
- **Iteration cap: 3.** A stubborn AC after 3 fix attempts signals an architectural or understanding problem the loop cannot crack. Log it, move on. The PROJ-end Quality Gate and Skill 6 QA will catch unresolved issues with fresh eyes — burning the orchestrator on a stuck loop is more expensive than letting one AC carry forward as a known gap.
- Cap-hit ACs are recorded under `### Ralph Cap Hit (Wave N, US-X)` in `progress.md` with: AC text, last 3 failure outputs, files touched, recommendation. Skill 6 QA reads these as priority test targets.

Update `progress.md` after each Ralph iteration.

### 5. Build check — handled by `wave-gate.sh`

Do not run an extra build between Ralph and the wave gate. Build is intentionally centralized:
- **Wave-end build:** `wave-gate.sh` runs `build_cmd` once per wave.
- **PROJ-end build:** the Quality Gate verifies the assembled PROJ before QA.

If a build failure is discovered by the wave gate, fix it immediately with the verbatim compiler output, then rerun the gate.

### 6. Write learnings to `agent.md`

After a US completes (or after a hard Ralph iteration), write any learnings to the source folder's `agent.md`. Include:
- Walls hit and how they were bypassed
- Surprising behavior in the framework/DB/tooling
- Patterns that worked well
- Dead ends (so future agents don't repeat them)

### 7. Wave review with CodeRabbit CLI

<HARD-GATE>
This step is MANDATORY. Do NOT skip it. Do NOT proceed to the smoke test or next wave without running CodeRabbit.
If CodeRabbit fails to execute (e.g., not installed, auth error), log the error in progress.md and inform the user — but do NOT silently skip it.
</HARD-GATE>

After the build check passes, run a CodeRabbit review on the wave's changes. This catches cross-cutting issues early — not at the end during the full Quality Gate.

```bash
# Record wave start commit if not already done
WAVE_BASE_SHA=$(git rev-parse HEAD~$(git log --oneline $WAVE_BASE_SHA..HEAD | wc -l) 2>/dev/null || echo $BASE_SHA)

# Run CodeRabbit review — MUST execute, not skip
coderabbit review --agent --base-commit $WAVE_BASE_SHA
```

Where `$WAVE_BASE_SHA` is the commit before this wave started (record it at the start of each wave, similar to `BASE_SHA` for the full feature).

**How to handle findings:**
- **Critical / High:** Fix immediately — spawn a fix teammate before the next wave. These would only get worse with more code on top.
- **Medium / Low:** Log to `progress.md` under the wave section. These are picked up by the full Quality Gate later.

**Log in progress.md:**
```markdown
### CodeRabbit Review
- Command: `coderabbit review --agent --base-commit $WAVE_BASE_SHA`
- Result: [PASS / findings found / ERROR with reason]
- Critical/High: [N found, N fixed]
- Medium/Low: [N logged for Quality Gate]
```

Update `$WAVE_BASE_SHA` to the current commit after the wave review passes.

### 7b. Browser smoke test (if wave touched frontend)

**Skip this step if the wave only contained backend-implementer teammates.**

After the CodeRabbit review, run a quick browser smoke test using `agent-browser` to verify that what was just built actually renders and works. This is NOT the full QA — it's a 60-second gut check.

```bash
# Ensure dev server is running first (npm run dev in background)
agent-browser --url http://localhost:3000/[route-affected-by-wave] \
  --prompt "Verify this page renders without errors. Check: (1) page loads fully, (2) no visible error messages or blank sections, (3) click the primary action of [US-N description] and confirm it works. Report PASS or FAIL with details."
```

For multiple pages affected by the wave, run one `agent-browser` call per route.

**Pass criteria:** Page renders, no visible errors, primary happy path works.
**Fail:** Stop and fix before the next wave — broken UI compounds fast.

Log the result in `progress.md` under the wave section:
```markdown
### Browser Smoke Test
- Pages tested: [list of URLs]
- Result: PASS / FAIL
- Details: [agent-browser output summary]
```

**Why agent-browser as an option?** It runs as a standalone CLI — no MCP context required. This means it can also be delegated to a teammate if needed. Full browser testing with Playwright or agent browser is reserved for the comprehensive QA in Step 10.

### 7c. Minimalism Review — moved to PROJ-end QA

Ken Takahashi (Minimalism / retrospective review) **no longer runs per wave**. CodeRabbit covers per-wave diff-review; Ken now runs once in Skill 6 against the assembled PROJ with PROJ-level scope. Rationale: per-wave Ken doubled review time without catching what CodeRabbit missed, and bloat is easier to spot in the full PROJ diff than in a single-wave diff.

Skip this step. Continue to Step 8 (wave-gate.sh).

<details>
<summary>Legacy details (kept for reference; do not run)</summary>

The previous per-wave Ken implementation lived here. It is removed in favor of a single PROJ-end Ken pass in Skill 6. The agent.md retrospective entries and AGENTS.md candidate harvesting still happen — just at PROJ scope, not wave scope.

Legacy invocation (per-wave Codex companion / general-purpose subagent at wave-base SHA) is removed. The same persona prompt now runs once at PROJ scope — see Step 9.

</details>

### 8. Mark wave complete, auto-continue to next wave

Run the Wave Gate script (see Wave Completion Gate above):

```bash
bash scripts/wave-gate.sh <N> <PROJ-X> <thema>
```

- Exit 0 → script appended `### Wave N Gate — PASSED` block to `progress.md`. Commit the wave. **Immediately proceed to next wave — do NOT pause, do NOT ask the user, do NOT announce "ready for next wave".** The gate already proved the wave is done; the next wave's Step 1 (read dependency map) is the next action.
- Non-zero → read the script's error, fix the failing check (spawn fix teammate if code problem, install missing tool if env problem), re-run. Only a red gate blocks progression — green means keep rolling.

**No stop between waves.** A PROJ with 5 waves should execute as one continuous run: wave 1 → gate ✓ → wave 2 → gate ✓ → … → wave 5 → gate ✓ → Step 9 Quality Gate. Pausing for user confirmation between waves defeats the wave-gate design — the gate IS the signal.

Manual checklist editing in progress.md is no longer sufficient proof of wave completion — only the script's passed-block counts.

### 9. Quality Gate (after all waves, before QA)

After all waves for this PROJ-X are complete and all ACs verified, run the Quality Gate.

See `references/quality-gate.md` for full instructions.

**Run all three gates in parallel using an agent team:**

```
Create an agent team for Quality Gate of PROJ-X.

Spawn teammates:
- "reviewer" using the code-reviewer-gate agent type with prompt:
  "Review the feature diff from BASE_SHA=$BASE_SHA. Check references/code-reviewer.md for the full checklist."
- "sonar" using the sonar-scanner-gate agent type with prompt:
  "Run SonarCloud scan and fetch issues for files changed since BASE_SHA=$BASE_SHA."
- "ken" using the general-purpose agent type (or codex companion if installed) with prompt:
  "You are Ken Takahashi, Minimalism Engineer with 20 years of experience (ex-kernel contributor, library author who ships small). SCOPE: only files touched between $BASE_SHA and HEAD — do NOT comment on unchanged code. Two questions: (1) Is every piece of NEW code earning its keep? Call out YAGNI, premature abstraction, layers with one caller, boilerplate duplicating framework features, dead pathways, speculative options. (2) What should we have done differently given what we know now? Propose concrete simplifications. Report Critical/High/Medium/Low findings with file:line. Separately emit 'agent.md retrospective' one-liners and 'AGENTS.md candidates' (≤ 120 chars each, project-wide rules). Pre-compute the diff: git diff --stat $BASE_SHA..HEAD > /tmp/ken-stat.txt and git diff $BASE_SHA..HEAD > /tmp/ken-diff.patch — review only that patch."
```

All three teammates report their findings. The lead consolidates results.

**Ken's outputs flow into:**
- Critical/High findings → fix-spawn cluster (same parallel-by-file pattern as code-reviewer findings).
- agent.md retrospective entries → append to relevant `src/features/<feature>/agent.md` under `## Retrospective (from Ken)`.
- AGENTS.md candidates → append to `## AGENTS.md Candidates` in `progress.md` with `— source: Ken Takahashi (Minimalism)`.

**After both teammates report — Handling Findings with Technical Rigor:**

Do NOT blindly implement every finding. Apply the `receiving-code-review` discipline:

1. **READ** each finding carefully — understand what the reviewer is flagging
2. **VERIFY** — Does this finding apply? Check the actual code. Reviewers (human or automated) can be wrong.
3. **EVALUATE** — Is this a real problem or a false positive?
   - **Push back when:** The finding breaks existing functionality, violates YAGNI (suggests "proper" patterns for unused scenarios), is technically incorrect, or conflicts with the user's explicit decisions
   - **YAGNI check:** If a reviewer suggests adding error handling for a scenario that can't happen, or abstracting code that's used once — grep the codebase for actual usage before implementing
4. **FIX** what's real — spawn fix teammates for confirmed P0/P1 and BLOCKER/CRITICAL/MAJOR issues
5. **LOG** P2/P3 and MINOR/INFO to `progress.md` — these are addressed if time permits
6. Clean up the team

**Exit criteria:**
- Zero P0/P1 code review findings
- Zero BLOCKER/CRITICAL/MAJOR sonar issues in feature files
- All tests passing, no new lint errors

Update `progress.md` with Quality Gate results.

### 10. QA + Fix Loop

**IMPORTANT:** The lead coordinates browser E2E testing (Playwright or agent browser + `npm run dev`). Code-level analysis runs in parallel as agent team teammates.

**How to run QA:** Create an agent team that splits QA work:

```
Create an agent team for QA of PROJ-X.

Spawn teammates:
- "red-team" using the red-team-tester agent type with prompt:
  "Test feature PROJ-X for security vulnerabilities and edge cases.
   Read PRDs at specs/PROJ-<X>-<thema>/3_PRDs/*.md for acceptance criteria.
   Focus on: injection attacks, auth bypass, boundary values, race conditions."
- "ui-audit" using the ui-auditor agent type with prompt:
  "Audit PROJ-X UI changes for design system compliance.
   BASE_SHA=$BASE_SHA. Check colors, typography, spacing, components, responsive."
```

**In parallel, the lead runs browser E2E testing directly:**
1. Start dev server (`npm run dev`)
2. Use Playwright or agent-browser tools to test every AC in the browser
3. Take snapshots and screenshots as evidence
4. Document findings

**After all QA sources report:**
1. Merge findings from lead (browser E2E), red-team, and ui-audit into `progress.md`
2. Clean up the team

```
while QA reports Critical or High bugs:
  for each Critical/High bug (in severity order):
    spawn fix teammate with: bug description + reproduction steps + verbatim failure output
    after fix: re-run the specific test that caught the bug to confirm it passes
  re-run relevant QA checks for full regression pass

if only Medium/Low bugs remain:
  present to user and ask: "Which bugs should be fixed before release?"
  fix user-selected bugs, then re-run QA one final time
```

**Rules:**
- Do NOT skip QA — it runs automatically after every Quality Gate, not on request.
- Browser E2E (Playwright or agent browser) MUST be coordinated by the lead; delegate only if the browser automation tool is available to the teammate.
- Red-team and ui-audit teammates work on code-level analysis in parallel with browser testing.
- Fix subagents receive the verbatim bug report from QA (never a summary).
- After each fix, re-run the specific failing test before the next QA pass.
- If the same bug persists after 3 fix attempts: escalate to user with full history.
- QA is considered clean only when it reports no Critical or High bugs.

Update `progress.md` with QA results. Mark this PROJ-X as complete.

---

## 11. Handoff to Skill 6 (QA)

<HARD-GATE>
Skill 5 does a first-pass QA in Step 10 (red-team + ui-audit + browser E2E) to catch Critical/High bugs before the Quality Gate proof. **Skill 6 is the comprehensive QA** with the six-persona panel (Chen/Weber/Sharma/Müller/Rodriguez/Takahashi) + PROJ Retrospective + AGENTS.md candidate collection.

Before invoking Skill 6, flush context:

1. Run `/compact`. Wave plans, agent chatter, Ralph iterations, and Quality-Gate review output are all on disk in `progress.md` — reclaim the context budget for Playwright or agent-browser testing + persona reviewers.
2. Verify `progress.md` Quality-Gate section is complete (code review + sonar findings logged).
3. Invoke Skill 6: `/6_qa` (interactive) or — in `autonomous-execution` mode — the orchestrator invokes it directly with `CLAUDE_AUTONOMOUS_LEVEL` still set.

**In autonomous mode** (`CLAUDE_AUTONOMOUS_LEVEL` env set, documented at `~/.claude/skills/autonomous-execution/SKILL.md` — Workflow section): skip the `/compact` user-prompt. The autonomous-execution orchestrator already scheduled a compact window between Skills 5 and 6.

**Do NOT skip Skill 6** even if Step 10 reported zero bugs. The persona panel and PROJ retrospectives produce `AGENTS.md` candidates and `## PROJ Retrospective` notes that Skill 7 consumes — skipping them means docs are incomplete.
</HARD-GATE>

## 12. Final Summary Report

After ALL PROJ-X plans are complete AND Skill 6 has finished, present a combined report:

> "All PROJ-X plans implemented and verified.
>
> ## PROJ-A: [topic]
> Implementation:
> - US-1: ✓ (N ACs, N Ralph iterations)
> - US-2: ✓ (N ACs, 0 Ralph iterations)
>
> Quality Gate:
> - Code Review: X found, X fixed, X deferred
> - SonarCloud: X found, X fixed, X deferred
>
> QA:
> - [N] bugs found, [N] fixed, [N] Medium/Low deferred
> - Production-ready: YES / NO
>
> ## PROJ-B: [topic]
> ...
>
> Learnings documented in `src/features/[feature]/agent.md`.
> Progress logs at `specs/PROJ-<X>-<thema>/7_progress/PROJ-<X>-progress.md`."

---

## Subagent Responsibility (per US)

Each subagent:
1. Reads `agent.md` if provided in the prompt
2. Implements all tasks for its US in order (TDD per task — see below)
3. Updates `progress.md` task row after each TDD cycle: tests written → tests passing → done
4. Runs an **inner Ralph loop** (2-stage review) after all tasks complete
5. Reports back with full detail

The subagent does NOT verify ACs — that is the main agent's outer Ralph loop.

### TDD cycle (per task)

No production code without a failing test first.

**RED:** Write one failing test. Run it — verify it fails for the expected reason (missing feature, not import error).

**GREEN:** Write the simplest code to pass. Run ALL tests — new + existing must pass.

**REFACTOR:** Remove duplication, improve names. No new behavior. Re-run tests.

Never claim a test passes without running the command and reading actual output.

### Inner Ralph loop (2-stage review, after all tasks in US)

```
while review not clean:
  Stage 1 — Spec compliance (references/spec-reviewer.md):
    read actual code, verify against task requirements
    if issues: fix (critical first), re-run tests, repeat Stage 1
  Stage 2 — Code quality (references/code-reviewer.md):
    only runs after Stage 1 passes
    if issues: fix, re-run tests, repeat Stage 2
```

Escalate to main agent only if a fix requires spec/architecture changes.

---

## When Something Breaks

Do NOT guess. Consult the `systematic-debugging` reference skill:

**Phase 1 — Root Cause Investigation:**
1. Read the full error message and stack trace — not a summary
2. Reproduce the failure consistently
3. Check `git diff` — what changed since it last worked?
4. Trace data flow from input to failure point

**Phase 2 — Hypothesis and Fix:**
1. Form ONE hypothesis, test with the smallest possible change
2. Write a failing test reproducing the bug, then fix
3. Run ALL tests — the fix must not introduce regressions

**The 3-Fix Rule:** If 3+ fix attempts fail on the same bug → STOP. This is an architectural or understanding problem. Escalate to the user with full iteration history.

**Always write the wall + workaround to `agent.md` when you find one.**

**Escalate to user if:**
- Outer Ralph has run 3+ iterations on the same AC
- Root cause is in the spec or architecture
- Missing dependency, broken environment, external service down
- Requirements are ambiguous or contradictory

---

## Commit Format

```
feat(PROJ-<X>-PRD-<Y>): implement [US-N task name]
fix(PROJ-<X>-PRD-<Y>): address review findings for [US-N]
fix(PROJ-<X>): address quality gate findings
```
