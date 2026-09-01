---
name: executing
description: "Execute implementation plans user-story by user-story in dependency order, using TDD, wave-scoped Ralph verification, wave gates, code review, and QA handoff. Use when: (1) an implementation plan exists and is ready for execution, (2) feature tasks need to be implemented with disciplined verification. Not for: planning, architecture, or requirements."
---

# Executing

Orchestrate implementation user story by user story. Workers own code, test, and fix edits; the lead owns decomposition, dispatch, integration, deterministic verification, gates, and operational records. After every worker in a wave finishes, the lead runs one wave-scoped Outer Ralph pass over that wave's acceptance criteria.

## Codex Adaptation

This skill was imported from a Claude workflow. In Codex, follow these overrides before any older wording below:

- Do not run `/compact`; Codex handles context compaction itself.
- Do not require `claude --dangerously-skip-permissions`, `.claude/settings.json`, or `bypassPermissions`. Use the current Codex session permissions and the normal approval/sandbox policy.
- Do not assume Claude agent teams, `Agent` tool syntax, `subagent_type`, or `run_in_background` fields exist.
- When Codex subagents are available and delegation is permitted, every code, test, and fix edit is worker-owned; there is no trivial-edit exception. Use `spawn_agent` roles available in Codex (`worker`, `explorer`, or default) with explicit file ownership and expected output.
- Dispatch independent tasks with disjoint ownership concurrently. Serialize dependencies and overlapping file ownership. Integration corrections go back to a follow-up worker with the exact failure; the lead does not patch them directly.
- Local implementation is allowed only when subagents are unavailable or delegation is prohibited. State that fallback reason explicitly in the user-visible update.
- Use `multi_tool_use.parallel` for safe parallel local reads and commands.
- Keep `.codex/skills` paths for reusable skill assets. Treat copied `.claude` permission templates as legacy references, not required setup.

**One PROJ at a time:** The executing loop runs per PROJ. Each PROJ has multiple wave-plan files (`PROJ-<X>-wave-1-plan.md`, `PROJ-<X>-wave-2-plan.md`, …) that are read in order. A single `5_progress/PROJ-<X>-progress.md` tracks all waves. When the user provides multiple PROJ plans, execute each PROJ fully (all waves → Quality Gate → QA) before starting the next.

**Decomposed PROJs:** If the plan references sibling PROJs, treat them as dependencies or context only. Do not implement sibling scope from the current PROJ's waves. If a wave depends on an incomplete sibling PROJ, stop before that wave and report the blocker. Shared design-language files from sibling PROJs may be consumed, but they do not authorize building sibling workflows.

## Context Economy

The orchestrator stays lean so it survives the full PROJ → QA → docs chain.

- Delegate every implementation and correction edit when Codex subagent policy permits it.
- Keep decomposition, dispatch, integration, deterministic checks, gates, state/findings/progress updates, and commits with the lead.
- Run disjoint work concurrently; serialize dependent or overlapping work.
- Keep subagent prompts narrow: paths, user-story ID, acceptance criteria, allowed files, expected output.
- Keep returned summaries short; do not paste raw diffs or long logs into the main context.
- If local work needs many file reads, first run focused searches and read only the files needed for the next decision.

## First Action (before reading any plan)

<HARD-GATE>
Before doing implementation work:
1. **P0 setup gate — setup (4b) owns all preflights.**
   - If `specs/PROJ-<X>-<theme>/state.json` exists:
     `bash scripts/state.sh get <X> <theme> '.phase + ":" + .status'` must be
     `P0:done` (fresh PROJ) or `P5:*` (resume). Anything earlier → STOP and
     route: `CP1:*` → run **checkpoint** (4a); `CP1:approved` → run
     **setup** (4b). The former inline preflights — `.coderabbit.yaml`,
     Supabase/browser/CLI + auth checks — now run in 4b's `preflight.sh`;
     do NOT re-run them here.
   - Then mark the phase if needed: if state shows `P0:done`, run
     `bash scripts/state.sh transition <X> <theme> P5 running`.
   - Verify the current directory is `.worktree.path` from state. P0 owns the
     persistent PROJ worktree and the runner re-executes there; do not implement
     from the control checkout. Dependencies are isolated, while `.env.local`,
     development data, and hosted-auth limits are deliberately shared.
2. **Standalone fallback (no state.json — manual run without the framework):**
   run the legacy preflights inline before wave 1: (a) `.coderabbit.yaml` at
   repo root (copy `~/.codex/skills/5_executing/references/coderabbit-template.yaml`,
   adjust `path_filters`); (b) tool checks — `jq`, `coderabbit`, Playwright MCP
   (`browser_navigate`, `browser_snapshot`, …) when `wave-gate-config.json`
   has `frontend_routes`, Supabase CLI/MCP when the project uses Supabase.
   Any hard tool missing → STOP.
3. Record BASE_SHA: from `state.json` (`.base_sha`, set by 4b) — standalone: `git rev-parse HEAD`
4. Create `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md` using the template below
5. Store BASE_SHA in progress.md

This file is your single source of truth for the whole PROJ. Update it after EVERY action.
If progress.md does not exist, you have skipped this step — STOP and create it now.
</HARD-GATE>

---

## Wave Completion Gate

<HARD-GATE>
Before spawning ANY teammate for a new wave N+1, you MUST run the Wave Gate script — it MUST exit 0.

Doc-input collection is owned by Skill 7. Do not fill documentation summaries or Post-Wave-Notes blocks during Skill 5. Keep `progress.md`, commit messages, and `agent.md` accurate; Skill 7 harvests those sources after QA.

```bash
bash scripts/wave-gate.sh <N> <PROJ-X> <theme>
```

Exit code ≠ 0 → STOP. Fix the failing check, re-run the script until green. Only then spawn the next wave's teammates.

For a provider signature only (`over_request_rate_limit`, `Request rate limit reached`, or HTTP/status 429), the gate pauses and retries that AC once. For auth-consuming browser commands, `auth_budget.rate_limit_evidence_cmd` may establish the same fact from server/provider evidence outside the Playwright stream; its output is retained. A second occurrence is red infrastructure, not a reason to widen limits. Other failures — including a test name containing “rate limit” — are ordinary red ACs.

Before P0 seals an auth-budget project, `bash scripts/wave-gate.sh --auth-budget-negative-control 1 <PROJ-X> <theme>` must return the configured exhausted exit code and persist `infrastructure_failed`. It exercises the configured hooks with `SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL=1` and never drains a real hosted bucket.

The script validates:
1. **Current wave ACs** — every structured `ac_commands` entry exits 0 and reports a non-empty selected-test count. A cached pass is reusable only for the same AC ID, command, positive selection, and committed `verified_head`; changed or uncommitted code cannot be certified.
2. **Declared targeted regressions** — every `regression_commands` entry covers shared behavior affected by this wave and runs after the current ACs and before build; selection-aware entries must prove that they selected tests. Broad hosted-auth/browser suites belong in `phase_commands`, not every wave.
3. **Build** — `build_cmd` from config exits 0.
4. **CodeRabbit** — every attempt archives raw and normalized evidence, validates the finding count, ingests it, and then requires zero cumulative open blocking findings in the ledger.
5. **Smoke Test** — the configured dev server is reused or started by the gate. Anonymous routes must match URL and characteristic content; redirects are failures. Protected routes require auth state or authenticated E2E coverage.

The wave gate does not run Sonar. The top-level `sonar_cmd` runs once, at the PROJ-end Quality Gate (Step 9) after all waves pass — not per wave.

A green wave gate proves the current wave's ACs plus its declared broad
regression suite. It does not claim that every earlier AC command was rerun.

On success the script appends a `### Wave N Gate — PASSED` block with timestamp to `progress.md`. This is the canonical proof that the wave is done — no manual checkbox editing.

**Framework runs (state.json exists):** after every green gate, update the machine state too — `bash scripts/state.sh set <X> <theme> .waves '{"current": <N>, "total": <M>, "stories": {…per-US status…}}'` (merge with the existing block). The gate pipes its normalized CodeRabbit findings into the ledger when `scripts/ledger.mjs` is present; Sonar evidence remains in the configured system — never re-enter either by hand.

**If the wave-gate.sh script is missing from the project:** copy the template from `~/.codex/skills/5_executing/scripts/wave-gate.sh` to `scripts/wave-gate.sh`, `chmod +x` it, commit it before running the first wave.

**If jq, coderabbit, or agent-browser are missing:** the script prints a clear error and exits non-zero. Install them, do not work around the gate.

**Belt-and-braces enforcement:** In Codex, enforce this in the main orchestration loop: before starting any Wave N with N > 1, verify `### Wave N-1 Gate — PASSED` exists in `5_progress/PROJ-<X>-progress.md`. The `wave-gate.sh` script is the primary gate.
</HARD-GATE>

---

## Memory Files

Two files are maintained throughout execution:

### `progress.md` (short-term memory)
Created at the start of execution, lives in `specs/` alongside the plan.
Tracks granular build state — task completion, test status, AC verification, and blockers.
Updated after every task, after the initial wave verification and each recovery stage, and whenever a blocker occurs.

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

### Wave-Scoped Ralph Evidence
- Initial pass: AC-1 PASS; AC-2 FAIL — [exact failure reason]
- Recovery stage: normal fix round 1 → follow-up worker dispatched
- Reused during repair: AC-1 — verified at [committed HEAD]; changed files not plausibly affecting it
- Rerun: AC-2 PASS — [exact command, positive selection, verified HEAD]
- Commit: `feat(PROJ-<X>-PRD-<Y>): implement US-1 [name]`

---

## US-2: [title] — pending
*(blocked by US-1)*

---

## Quality Gate — PROJ-X

### Code Review
Status: pending | passed
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| P0 Critical | 0 | 0 | 0 |
| P1 High | 0 | 0 | 0 |
| P2 Medium | 0 | 0 | 0 |
| P3 Low | 0 | 0 | 0 |

### SonarCloud (once per PROJ, via top-level `sonar_cmd`)
Status: pending | ran | skipped (sonar CLI unavailable) | skipped (project not configured)
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| Critical/Major | 0 | 0 | 0 |
| Minor | 0 | 0 | 0 |
| Info | 0 | 0 | 0 |

### Build
Status: pending | passed

### Tests
Status: pending | passed

### Lint
Status: pending | passed

### Fixed Issues
- [severity]: `file:line` — [issue] → fixed in [commit]

### Deferred (user decision)
- [severity]: `file:line` — [issue]

---

## Open Blockers
- US-7: [exact reason] — escalated to user [timestamp]
```

**Update rules:**
- Subagent updates task rows after each TDD cycle (tests written → tests passing → done)
- Main agent updates AC rows after the initial wave pass and every recovery stage
- `—` means not yet attempted; `✗` means attempted and failing; `✓` means passing
- Wave-Scoped Ralph Evidence records canonical AC, command, positive selection, committed HEAD, reuse/invalidation, and verbatim failure output

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

**All PRDs** — `specs/PROJ-<X>-<theme>/2_PRDs/*.md`. These are the authoritative requirements source. Used by the wave-scoped Outer Ralph pass to verify ACs. If plan and PRD disagree on AC text, the PRD wins.

**Architecture** — `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md`. Cross-PRD tech design.

**Wave plans** — `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-wave-<N>-plan.md` (in numeric order). Each wave plan lists:
- The user stories in that wave (may span multiple PRDs)
- Tasks per US with TDD cycle descriptions and file paths
- For UI tasks, UI Implementation Notes and UI handoff constraints propagated from `1d_mockups/implementation-handoff.md`

**UI implementation handoff** — for UI PROJs, read `specs/PROJ-<X>-<theme>/1d_mockups/implementation-handoff.md` before starting implementation. It is the compact source for project mode, component reuse, new component candidates, design tokens, interaction contract, implementation tolerance, and demo-only mockup exclusions.

The PRDs define WHAT success means. The wave plans define HOW to get there. The UI handoff defines how to preserve the approved interface shape without treating HTML mockups as pixel-perfect production specs.

**When multiple PROJ plans are provided:** Execute one PROJ fully (all waves → Quality Gate → QA) before starting the next. Each PROJ has its own `5_progress/PROJ-<X>-progress.md`.

---

## Per-PROJ-X Execution Loop

For each PROJ-X plan (in order):

```
0. Record BASE_SHA (git rev-parse HEAD)
1. Create specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md
2. Execute waves (Steps 1–5 below)
3. One wave-scoped Outer Ralph pass, then the wave-end gate: ACs + regressions + Build + CodeRabbit + Smoke (Steps 4 and 8)
4. Quality Gate after all waves (Step 9)
5. Handoff directly to mandatory Skill 6 QA (Step 10)
6. Mark Step 5 complete
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
Wave 2: US-2, US-7 (parallel)   → 2 teammates simultaneously
Wave 3: US-3                    → 1 teammate
...
```

### 2. Before each wave: read `agent.md`, refresh the context bundles

If `agent.md` exists in the source folder, read it before spawning teammates.
Include relevant sections in the teammate prompt so they don't repeat known dead ends.
(Implementers additionally follow the agent.md read/write protocol in `references/implementer.md`;
entries are rendered with `templates/agent-md-entry.md.tmpl`.)

When `specs/.../api-contracts.md` has entries for this wave, recompile the bundles
wave-scoped so `api-contracts-own-wave` is real, and record the new hashes:

```bash
node scripts/compile-context-bundles.mjs compile <X> <theme> --wave <N>
bash scripts/state.sh set <X> <theme> .context.bundles "$(jq -c . specs/PROJ-<X>-<theme>/context/bundles.lock.json)"
```

### 2a. Mark wave start with a git tag

<HARD-GATE>
Before spawning any teammate for wave N, tag the current HEAD as the wave base. `wave-gate.sh` resolves this tag to scope the CodeRabbit diff. Without the tag or an explicit `WAVE_BASE_SHA`, the gate fails hard. This prevents accidentally reviewing broad branch history.
</HARD-GATE>

```bash
git tag "wave-${WAVE}-start-PROJ-${PROJ}"
```

One tag per (wave, PROJ) pair. Tags are local-only; do not push. If neither `WAVE_BASE_SHA` nor `wave-${WAVE}-start-PROJ-${PROJ}` exists, `wave-gate.sh` fails hard. There is no `HEAD~20`, commit-message, or root-commit fallback. If the tag already exists from a re-run, delete and re-create: `git tag -d "wave-${WAVE}-start-PROJ-${PROJ}"`.

### 3. Create team and spawn teammates for the wave

All implementation work is worker-owned when delegation is available. The lead decomposes the wave, assigns explicit disjoint ownership, dispatches workers, integrates their commits, runs deterministic verification and gates, and maintains operational records. **For waves with 2+ independent user stories:** create an agent team and dispatch them concurrently. Serialize dependent stories or any work with overlapping ownership.

**Honor the plan's `## Execution` block before spawning.** `sequential` means
dispatch exactly one US at a time even when `Can start when` says both are
ready. For any frontend wave, the lead owns the dev server: start and stop it
once for the round; agents reuse it and never start or kill one. For a parallel
wave, the lead also owns every other declared shared resource and the control
plane: `progress.md`, staging, and commits. Include the execution mode, runtime
constraints, and these ownership rules in every spawn prompt.

The development database and hosted-auth budget are shared across the PROJ
worktrees. Every database migration command—including one delegated to a story
agent—and every other explicitly `auth_consuming` command must therefore be
wrapped as `scripts/worktree.sh with-shared-lock -- <command>`. Put that exact
constraint in the agent prompt; never let parallel agents run migrations
outside the project lock. That lock only stops concurrent collisions;
`wave-gate.sh` separately re-checks at the start of every wave that this
worktree's own `supabase/migrations/` still matches what the shared DB has
actually applied (`scripts/migration-drift-check.sh`), since a sibling
worktree can advance the schema between waves with no lock involved at all.

**Choose the right implementer type per US.** Where the current session can
spawn P0's `skillchain-<role>` agent types, use them. Otherwise use the normal
agent type and attach the path printed by
`node scripts/context-injector.mjs codex <role> --path` to its prompt; a
non-zero exit means that role is blocked and must not be spawned. A generic
`general-purpose` spawn gets no bundle unless that path is explicitly passed:
- US touches only UI (components, pages, styling) → `frontend-implementer` (`skillchain-frontend-implementer`)
- US touches only server-side (API, DB, server actions) → `backend-implementer` (`skillchain-backend-implementer`)
- US is full-stack (both UI and server logic) → `implementer` (generic)

**Choose the right model per US (from the wave plan's `Complexity` column):**
Read the `Complexity` column in the wave plan's "User Stories in this Wave" table. Pass the value as the `model` parameter on the `Agent` spawn so the teammate runs on the right brain for the job.
- `sonnet` → `model: "sonnet"` (default for standard US)
- `opus` → `model: "opus"` (architecture-sensitive: state machines, concurrency, cross-feature contracts, migrations, auth/session, money, crypto)

Haiku is deliberately not in the menu — US-level work loses too much fidelity on it. If the wave plan is missing the `Complexity` column (older plan format), default to `sonnet` and log a one-line note in `5_progress/PROJ-<X>-progress.md` so the planner can retrofit it.

```
Create an agent team for Wave N of PROJ-X.

Spawn teammates:
- "us-2" using the frontend-implementer agent type, model: "sonnet": [US-2 prompt with full context]
- "us-7" using the backend-implementer agent type, model: "opus": [US-7 prompt with full context — this one touches auth/session]

Require plan approval for each implementer before they make changes.
```

**For waves with a single user story:** Use a regular subagent (no team overhead needed). Pick the matching implementer type based on the US scope. Local editing is permitted only when delegation is unavailable or prohibited; report that reason explicitly.

Pass to each teammate (via `references/implementer.md` template):
- Full user story (Given/When/Then)
- Its acceptance criteria
- Its task list with TDD steps
- Codebase context + conventions
- What previous waves implemented
- Relevant sections from `agent.md`
- **If the US touches UI:** include the relevant `UI Implementation Notes` from the wave plan and the matching sections from `1d_mockups/implementation-handoff.md`:
  - Project mode (`greenfield`, `brownfield`, `hybrid`)
  - Mockup file reference and selected UI direction
  - Existing components/tokens to reuse
  - Approved new component candidates
  - Required interaction contract and responsive behavior
  - Implementation tolerance and demo-only exclusions
- **If the US touches UI:** the design system baseline is `docs/DESIGN-SYSTEM.md` (rules) plus `docs/components.md` (inventory). In framework runs the `frontend-implementer` context bundle injects both — do not paste them again, that pays the token budget twice. Outside bundle runs, paste both files. Either way the teammate reuses registered components — never one-off styled elements.
- **If a US needs a component the catalog does not have:** the teammate escalates instead of styling a one-off. The lead agent runs the extension procedure from `1c_frontend-design` → *Extending The Design System* (variant before new component, confirm with the user, then catalog + `docs/components.md` + `/dev/components` showcase), then the teammate composes the new entry. A component that reaches QA without a catalog and registry entry is a Critical bug (`6_qa` hard-checks this).
- **If the US touches Tailwind CSS styling:** Include the contents of `~/.codex/skills/tailwind-css/SKILL.md`. Pass the relevant sections (responsive patterns, dark mode, class organisation, component patterns) so the teammate uses consistent utility classes and avoids conflicts.
- **If the US involves Next.js App Router:** Include the contents of `~/.codex/skills/nextjs-app-router-patterns/SKILL.md`. Pass the relevant sections (Server vs. Client Components, data fetching, routing, caching) so the teammate follows App Router conventions and avoids common pitfalls (e.g. accidentally marking a Server Component as `'use client'`).

**UI implementation rule:** Existing React components and design tokens take precedence over exact HTML mockup CSS. Preserve the selected layout direction and interaction contract; do not replace a sidepanel with a modal, a wizard with a single page, or a brownfield component with a one-off styled element unless the user explicitly approved that change.

Wait for all teammates in the wave to complete before running Outer Ralph. If integration or verification exposes a correction, dispatch it to a follow-up worker; do not absorb the edit into the lead. Clean up the team after each wave.

### 4. Wave-scoped Outer Ralph (AC verification)

<HARD-GATE>
After ALL workers in the wave report back and their changes are integrated, run one wave-scoped Outer Ralph pass. Run no story-scoped Outer Ralph pass. Do not proceed to the wave gate until the bounded recovery below passes or reaches the existing blocked path.
</HARD-GATE>

The lead starts the pass through the gate's AC-only mode so evidence is written in the canonical cache schema:

```bash
bash scripts/wave-gate.sh --ac-only <N> <X> <theme>
```

It runs each uncached AC sequentially under the gate's timeout, auth-budget, pacing, and rate-limit controls. Ordinary AC failures are all evidenced before the pass exits non-zero so disjoint repairs can be batched; infrastructure and exhausted auth budgets still stop immediately. Each evidence record binds the canonical AC ID, task, exact command, test files, positive selected-test count, and committed `HEAD`.

```
run bash scripts/wave-gate.sh --ac-only <N> <X> <theme>
for normal_fix_round in 1..2:
  cluster failures by disjoint ownership
  dispatch correction workers concurrently where safe
  commit corrections, then rerun the same --ac-only command
if failures remain:
  dispatch one fresh diagnostic worker that makes no edits
  dispatch a different implementer to apply the diagnosis
  commit the correction, then rerun the same --ac-only command
if failures still remain: use the existing blocked-run evidence path
```

**Rules for wave-scoped Ralph:**
- Checks must be **deterministic** — run actual test commands, read actual output. No subjective judgment ("this looks like it works").
- A test that depends on state outside itself — provider rate budget, file order, or clock — must establish that state itself or explicitly assert it. Never accept a green result merely because neighbouring tests primed the bucket or fixture.
- Treat “nothing happened” as weak evidence: add a positive control that proves the valid session/input/path would have worked, and do not let polling matchers pass on their first attempt without proving the observed transition.
- Failure output is passed **verbatim** to correction and diagnostic workers — not summarized or interpreted.
- The cache is deliberately conservative: only an exact AC ID + command match at the same committed `HEAD` is reused. Every correction commit changes `HEAD`, so `--ac-only` reruns all ACs; no cross-HEAD impact inference is supported.
- Recovery has exactly four stages: normal fix round 1, normal fix round 2 with fresh workers, fresh diagnosis, then a different diagnosis-driven implementer. Do not add retries or silently weaken an AC.
- If diagnosis finds an invalid or contradictory AC, record the evidence and use the existing blocked/escalation path.
- The normal wave gate remains the hard boundary and reuses exact same-HEAD AC-only passes, then still runs the declared regression suite and every remaining gate phase. Any committed or non-evidence uncommitted change prevents reuse.

Update `progress.md` after the initial pass, each recovery stage, each reuse or invalidation decision, and the final result.

### 5. No standalone build check

Do not run an extra build between Ralph and the wave gate. Build is intentionally centralized:
- **Wave-end build:** `wave-gate.sh` runs `build_cmd` once per wave.
- **PROJ-end build:** the Quality Gate verifies the assembled PROJ before QA.

If the wave gate finds a build failure, dispatch a fix worker with the verbatim compiler output, then rerun the gate.

### 6. Write learnings to `agent.md`

After a wave worker completes or a recovery stage exposes a durable learning, write it to the source folder's `agent.md`. Include:
- Walls hit and how they were bypassed
- Surprising behavior in the framework/DB/tooling
- Patterns that worked well
- Dead ends (so future agents don't repeat them)

### 7. Wave review with CodeRabbit CLI

<HARD-GATE>
CodeRabbit is MANDATORY, but it is run by `wave-gate.sh`, not as a separate pre-gate command. Do NOT run a second per-wave review outside the gate.
If CodeRabbit fails to execute (e.g., not installed, auth error), the gate exits non-zero. Fix the tool/auth problem and rerun the gate.
</HARD-GATE>

The wave gate runs CodeRabbit on the wave's changes. This catches cross-cutting issues early — not only at the end during the full Quality Gate.

```bash
bash scripts/wave-gate.sh <N> <PROJ-X> <theme>
```

The base commit must be either `WAVE_BASE_SHA` or tag `wave-${WAVE}-start-PROJ-${PROJ}`. Missing base = hard fail. No fallback is allowed.

**How to handle findings:**
- Each gate attempt retains `coderabbit-wave-<N>-attempt-<M>.jsonl` and its normalized sibling; never overwrite earlier review evidence.
- Any cumulative open ledger severity not listed in the wave's `advisory_severities` blocks. Fix immediately — spawn a fix teammate before the next wave.
- Listed advisory severities are logged by CodeRabbit output and revisited at the PROJ-end Quality Gate if still relevant.

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

Browser smoke testing is owned by `wave-gate.sh`. If the wave touched frontend routes, the gate reuses a matching reachable server or starts `frontend.dev_cmd`, waits for readiness, logs its output, and stops only the process it started. It then runs `agent-browser` to verify that what was just built actually renders and works. This is NOT the full QA — it is a short deterministic route check.

```bash
# The lead owns this server for the wave; do not start or stop another one.
agent-browser open http://localhost:3000/[route-affected-by-wave]
agent-browser read
agent-browser errors
```

For multiple pages affected by the wave, run one `agent-browser` call per route.

**Pass criteria:** Anonymous routes keep the expected URL and characteristic text. Protected routes supply `auth_state`, or the declared regression suite provides authenticated E2E coverage.
**Fail:** Stop and fix before the next wave — broken UI compounds fast.

Log the result in `progress.md` under the wave section:
```markdown
### Browser Smoke Test
- Pages tested: [list of URLs]
- Result: PASS / FAIL
- Details: [agent-browser output summary]
```

**Why agent-browser instead of Playwright MCP?** It runs as a standalone CLI — no MCP context required. This means it can also be delegated to a teammate if needed. Full Playwright MCP testing is reserved for comprehensive QA in Skill 6.

### 7c. Minimalism Review — Ken Takahashi

<HARD-GATE>
Ken does **not** run per wave. CodeRabbit is the only per-wave review. Ken runs once at PROJ end in Skill 6, after all waves have assembled into a complete feature.
</HARD-GATE>

Do not invoke Ken from Skill 5. Do not create Ken wave BUG IDs or Ken wave backlog sections. If minimalism concerns appear during implementation, write them as normal `agent.md` learnings or progress notes; Skill 6 will review the complete PROJ diff with Ken's PROJ-level lens.

### 8. Mark wave complete, auto-continue to next wave

Run the Wave Gate script (see Wave Completion Gate above):

```bash
bash scripts/wave-gate.sh <N> <PROJ-X> <theme>
```

- Exit 0 → script appended `### Wave N Gate — PASSED` block to `progress.md`. Commit the wave. **Immediately proceed to next wave — do NOT pause, do NOT ask the user, do NOT announce "ready for next wave".** The gate already proved the wave is done; the next wave's Step 1 (read dependency map) is the next action.
- Non-zero → read the script's error, fix the failing check (spawn fix teammate if code problem, install missing tool if env problem), re-run. Only a red gate blocks progression — green means keep rolling.

**No stop between waves.** A PROJ with 5 waves should execute as one continuous run: wave 1 → gate ✓ → wave 2 → gate ✓ → … → wave 5 → gate ✓ → Step 9 Quality Gate. Pausing for user confirmation between waves defeats the wave-gate design — the gate IS the signal.

Manual checklist editing in progress.md is no longer sufficient proof of wave completion — only the script's passed-block counts.

### 9. PROJ Quality Gate (integration only, after all waves)

After all waves for this PROJ-X are complete and their gates passed, run the Quality Gate. It evaluates the assembled cross-wave result; it does not replay wave ACs or replace the wave gates.

See `references/quality-gate.md` for full instructions.

**Run Gate 1, the PROJ-end build, and Sonar in parallel where safe:**

Sonar runs exactly once per PROJ, here — no wave gate runs it. Skip is allowed
only when the tooling genuinely is not available; `scripts/quality-gate-proof.sh`
rejects a skip when both CLIs and `sonar-project.properties` are present, so
treat this as required whenever the project is Sonar-configured.

Before launching the Sonar stream, check tool availability:

```bash
command -v sonar >/dev/null && command -v sonar-scanner >/dev/null
```

- If both CLIs are available, run the Sonar quality-gate stream using the `sonar-cli` skill guidance, executing the top-level `sonar_cmd` from `wave-gate-config.json` as the analysis command.
- If either CLI is missing, skip Sonar and record `SonarCloud: skipped (sonar CLI unavailable)` in `progress.md`.

```
Create an agent team for Quality Gate of PROJ-X.

Spawn teammates:
- "reviewer" using the code-reviewer-gate agent type with prompt:
  "Review the feature diff from BASE_SHA=$BASE_SHA. Check references/code-reviewer.md for the full checklist."
- "sonar" only if `sonar` and `sonar-scanner` are installed, using the sonar-cli skill with prompt:
  "Run the once-per-PROJ Sonar scan: execute the top-level sonar_cmd from wave-gate-config.json from the persistent PROJ worktree, then use sonar CLI/API for quality gate, issue, coverage, and duplication data. Verify a fresh .scannerwork/report-task.txt after sonar_cmd exits 0 so a silent no-op doesn't read as green. If project Sonar config is absent, log SonarCloud as skipped rather than blocking."
```

The lead also runs `build_cmd` and every `phase_commands` entry marked
`quality` from `wave-gate-config.json` once for the assembled PROJ. CI/nightly
entries are verified as wired to their named workflows, not replayed locally. The lead
consolidates reviewer, build, integration/quality-phase, and Sonar results. Do not rerun `ac_commands`; their canonical proof belongs to wave-scoped Ralph and `wave-gate.sh`.

**After both teammates report — Handling Findings with Technical Rigor:**

Do NOT blindly implement every finding. Apply this discipline:

1. **READ** each finding carefully — understand what the reviewer is flagging
2. **VERIFY** — Does this finding apply? Check the actual code. Reviewers (human or automated) can be wrong.
3. **EVALUATE** — Is this a real problem or a false positive?
   - **Push back when:** The finding breaks existing functionality, violates YAGNI (suggests "proper" patterns for unused scenarios), is technically incorrect, or conflicts with the user's explicit decisions
   - **YAGNI check:** If a reviewer suggests adding error handling for a scenario that can't happen, or abstracting code that's used once — grep the codebase for actual usage before implementing
4. **FIX** what's real — spawn fix teammates for confirmed P0/P1; for Sonar BLOCKER/CRITICAL/MAJOR, run the bounded 3-round fix-and-rescan loop from `references/quality-gate.md` Gate 3 step 6 (dispatch disjoint fixes concurrently, overlapping fixes serially)
5. **LOG** P2/P3, Sonar MINOR/INFO, and any Sonar BLOCKER/CRITICAL/MAJOR still open after 3 rounds to `progress.md` as carried-forward — these never block or escalate
6. Clean up the team

**Exit criteria:**
- Zero P0/P1 code review findings
- `build_cmd` from `wave-gate-config.json` passes once for the assembled PROJ
- Every `quality` phase command passes once; CI/nightly workflow wiring is verified
- If Sonar ran: zero BLOCKER/CRITICAL/MAJOR sonar issues, or every remaining one is documented as carried-forward after the 3-round fix loop (carried-forward Sonar issues do not block this gate)
- If Sonar was skipped because CLIs or project config were unavailable: the skip reason is logged in `progress.md`
- Declared integration/quality-phase tests passing, no new lint errors

Update `progress.md` with Quality Gate results.

## 10. Handoff to Skill 6 (QA)

<HARD-GATE>
Skill 5 stops after implementation, wave gates, and the integration-focused PROJ Quality Gate. **Skill 6 is the mandatory comprehensive QA** with the six-persona panel (Chen/Weber/Sharma/Mueller/Rodriguez/Takahashi) + PROJ Retrospective + AGENTS.md candidate collection.

**Framework runs (state.json exists):** seal the phase first —
`bash scripts/quality-gate-proof.sh <X> <theme>` MUST exit 0 first, then run
`bash scripts/state.sh transition <X> <theme> P5 done`. The phase runner
then starts P6 as fresh lanes (read-only QA finder + P6 controller);
do NOT continue into Skill 6 inside this session.

Before invoking Skill 6 (interactive runs):

1. Verify wave plans, wave-scoped Ralph recovery stages, and Quality-Gate review output are all summarized in `progress.md`.
2. Run `bash scripts/quality-gate-proof.sh <X> <theme>`; it rejects a missing
   section, build evidence, or Sonar disposition, and rejects a Sonar skip when
   the configured scanner was available.
3. Suggest that the user run QA with a different model than the one that executed the implementation, for example GPT reviewing Claude-built work or Claude reviewing GPT-built work.
4. Invoke Skill 6: `/6_qa`. Skill 6 follows its own release gate and hands passing or Medium/Low-only work directly to Skill 7.

**Do NOT skip Skill 6.** Step 5 deliberately performs no duplicate QA stage; the persona panel and PROJ retrospectives produce `AGENTS.md` candidates and `## PROJ Retrospective` notes that Skill 7 consumes.
</HARD-GATE>

## 11. Final Summary Report

After ALL PROJ-X plans are complete AND Skill 6 has finished, present a combined report:

> "All PROJ-X plans implemented and verified.
>
> ## PROJ-A: [topic]
> Implementation:
> - Wave 1: ✓ (N ACs, recovery stage reached: initial | fix-1 | fix-2 | diagnosis | diagnosis-fix)
> - Wave 2: ✓ (N ACs, recovery stage reached: ...)
>
> Quality Gate:
> - Code Review: X found, X fixed, X deferred
> - SonarCloud: X found, X fixed, X deferred OR skipped (reason)
>
> QA:
> - [N] bugs found, [N] fixed, [N] Medium/Low deferred
> - Production-ready: YES / NO
>
> ## PROJ-B: [topic]
> ...
>
> Learnings documented in `src/features/[feature]/agent.md`.
> Progress logs at `specs/PROJ-<X>-<theme>/5_progress/PROJ-<X>-progress.md`."

---

## Subagent Responsibility (per US)

Each implementation subagent:
1. Reads `agent.md` if provided in the prompt
2. Implements all tasks for its US in order (TDD per task — see below)
3. Reports task status after each TDD cycle; the lead updates `progress.md` and commits for parallel waves
4. Runs one bounded **Inner Ralph self-review** after all tasks complete
5. Reports back with full detail

The subagent does NOT verify ACs — that belongs to the lead's wave-scoped Outer Ralph pass.

### TDD cycle (per task)

No production code without a failing test first.

**RED:** Write one failing test. Run it — verify it fails for the expected reason (missing feature, not import error).

**GREEN:** Write the simplest code to pass. Run ALL tests — new + existing must pass.

**REFACTOR:** Remove duplication, improve names. No new behavior. Re-run tests.

Never claim a test passes without running the command and reading actual output.

### Inner Ralph self-review (one bounded pass, after all tasks in US)

```
review the completed story once for:
  - task/spec compliance
  - error handling, type safety, test quality, and architecture
fix confirmed issues within the worker's ownership
run targeted tests once after the fixes
report any unresolved issue to the lead; do not start another self-review cycle
```

Escalate to main agent only if a fix requires spec/architecture changes.

---

## When Something Breaks

Do NOT guess. Follow `references/debugging.md`:

**Phase 1 — Root Cause Investigation:**
1. Read the full error message and stack trace — not a summary
2. Reproduce the failure consistently
3. Check `git diff` — what changed since it last worked?
4. Trace data flow from input to failure point

**Phase 2 — Hypothesis and Fix:**
1. Form ONE hypothesis, test with the smallest possible change
2. Write a failing test reproducing the bug, then fix
3. Run ALL tests — the fix must not introduce regressions

**Bounded recovery:** Wave AC failures use exactly the four Outer Ralph recovery stages in Step 4. Other repeated implementation failures use the existing blocked/escalation path with full attempt history.

**Always write the wall + workaround to `agent.md` when you find one.**

**Escalate to user if:**
- Wave-scoped Outer Ralph exhausted both normal fixes, fresh diagnosis, and the diagnosis-driven implementation
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

## Legacy Folder Layout

PROJ folders created before the layout rename use different subfolder
names. Mapping, old → current:

`2_visual-companion/` → `1b_visual-companion/` · `4_design/` → `1c_design/` ·
`5_mockups/` → `1d_mockups/` · `3_PRDs/` → `2_PRDs/` ·
`8_handoff/` → `2b_handoff/` · `6_plan/` → `3-4_plan/` ·
`7_progress/` → `5_progress/`

If an expected folder is missing but its legacy twin exists, **read from the
legacy one and keep writing where the existing files already are**. Never
create a second folder next to it — a split PROJ is worse than an old name.
Say it once, then continue either way:

> "This PROJ uses the old folder layout (`<old>`). Rename the folders to the
> current names, or continue with the existing layout?"

Renaming is a `git mv` per folder plus a search for the old paths in the
PROJ's own documents. It is never a precondition for this skill.
