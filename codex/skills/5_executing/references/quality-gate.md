# Quality Gate

Runs once per PROJ-X after all waves complete and their wave gates pass.
Must pass before handing off to QA.

## Prerequisites

- All waves complete with passed wave-gate proof
- Record `BASE_SHA` (commit before first implementation change) at the start of execution

## Gate 0: Declared Quality-Phase Tests

Read `phase_commands` from `wave-gate-config.json` and run each entry whose
`phase` is `quality` exactly once against the assembled PROJ. Preserve its
output and require a non-zero selected-test count. Do not replay `ci` or
`nightly` entries locally; verify their workflow wiring. Delivery owns the
actual PR CI result.

Wave commands already proved the newly built behavior. This gate is for broader
assembled-PROJ coverage, not another run of every wave AC.

---

## Gate 1: Code Review Expert

Review cross-wave integration across the feature diff: contracts between waves, shared state, authorization boundaries, and unresolved earlier findings. Consult wave review evidence first; do not repeat its generic checklist or the six-persona QA panel. Do not replay wave ACs here.

### Steps

1. Get the feature diff:
   ```bash
   git diff BASE_SHA..HEAD --stat    # scope overview
   git diff BASE_SHA..HEAD -- <affected-paths>  # follow cross-wave interfaces
   ```

2. Use `references/code-reviewer.md` only for checks relevant to an identified integration risk. Start with the diff stat, then read affected interfaces and their callers. Expand to the full diff when the dependency trace requires it. Do not create speculative SOLID, memoization, or redesign work without an observed defect.

3. Classify findings by severity:
   - **P0 Critical** — Security vulnerability, data loss risk, correctness bug → must fix
   - **P1 High** — Logic error, broken cross-wave contract, performance regression → must fix
   - **P2 Medium** — Code smell, maintainability concern → log for user decision
   - **P3 Low** — Style, naming, minor suggestion → log only

4. Tag every finding with one axis and report the two axes separately, never merged or reranked:
   - **Spec** — diff vs. PRD/AC/wave plan: missing or partial requirement, wrong implementation, behavior nobody asked for (scope creep). Cite the PRD/AC line.
   - **Standards** — diff vs. `AGENTS.md`, `docs/ARCHITECTURE.md` and other documented conventions; code smells are judgement calls. Cite the rule. Skip what tooling enforces.

   A change can pass one axis and fail the other; neither masks the other.

5. Return confirmed P0/P1 to the coordinator. Wait for build, quality tests and Sonar results before the combined recovery round below; reviewers do not start an independent fix loop. Re-review the combined fix diff afterward.

6. Log P2/P3 to `5_progress/PROJ-<X>-progress.md` under the Quality Gate section.

---

## Gate 2: PROJ-End Build

Run `node scripts/quality-evidence.mjs <X> <theme> run build`. The helper reuses the final wave build only when configured `build_artifacts` still match and code, configuration, environment, Node runtime and dependency-install fingerprints are unchanged. Without declared artifacts it builds normally. Declare artifacts only for builds independent of external state; remove build/coverage evidence after manual toolchain/dependency changes or untracked external input changes. Fixes invalidate old proof; verify the combined revision after recovery.

---

## Gate 3: Sonar Scan (once per PROJ)

Sonar runs at PROJ end, with an initial scan and at most three fix/rescan rounds; no wave gate runs Sonar. Each scan analyzes all waves together.

### Preflight

```bash
command -v sonar >/dev/null && command -v sonar-scanner >/dev/null
```

- If both commands exist, run this gate using the `sonar-cli` skill guidance.
- If either command is missing, skip this gate and record `SonarCloud: skipped (sonar CLI unavailable)` in `5_progress/PROJ-<X>-progress.md`.
- If both commands exist but the project has no Sonar config and no explicit user/plan requirement to create one, skip this gate and record `SonarCloud: skipped (project not configured)`.
- `scripts/quality-gate-proof.sh` rejects a skip when both CLIs and `sonar-project.properties` are present — treat this gate as required whenever the project is Sonar-configured.

### Steps

1. Run the exact top-level `sonar_cmd` from `wave-gate-config.json` (the same
   command used to describe the scan in the plan) from the persistent PROJ
   worktree:
   ```bash
   node scripts/quality-evidence.mjs <X> <theme> run sonar
   ```
   Do not substitute an ad hoc `sonar-scanner` invocation — reuse the
   configured command so there is one source of truth for how this project is
   scanned. Wait for the scan to complete before proceeding.

2. Confirm the scan actually ran, not a silent no-op: `sonar_cmd` exiting 0
   is not sufficient proof by itself — `sonar analyze`/`sonar verify` alone can
   exit 0 having checked nothing. Require a `.scannerwork/report-task.txt`
   (only `sonar-scanner` writes this) with an mtime at or after this step's
   start.

3. Fetch current Sonar issues, measures, and quality-gate status:
   ```bash
   BRANCH=$(git rev-parse --abbrev-ref HEAD)
   sonar list issues --project <project-key> --branch "$BRANCH" --page-size 500
   sonar api get "/api/measures/component?component=<project-key>&metricKeys=bugs,vulnerabilities,code_smells,security_hotspots,coverage,duplicated_lines_density,ncloc"
   sonar api get "/api/qualitygates/project_status?projectKey=<project-key>"
   ```

4. Filter issues to files changed by this feature: `git diff BASE_SHA..HEAD --name-only`.

5. Classify by SonarCloud severity:
   - **BLOCKER / CRITICAL** → must fix
   - **MAJOR** → must fix (treat as P1)
   - **MINOR** → log for user decision
   - **INFO** → log only

6. Return BLOCKER/CRITICAL/MAJOR findings to the coordinator's combined recovery round below, up to three Sonar fix/rescan rounds. Do not independently rerun tests or dispatch fixes from the Sonar stream.
   - Each round's scan must independently satisfy step 2's no-silent-no-op check — a round that produces no fresh `.scannerwork/report-task.txt` did not run and cannot count toward the 3.
   - Update `scripts/sonar-tracker.md` if it exists (mark fixed items `[x]`) after every round.
   - **If BLOCKER/CRITICAL/MAJOR issues remain after round 3:** document each one in `5_progress/PROJ-<X>-progress.md` (file, line, rule, severity, what the last fix attempt changed and why the issue persisted). Do **not** escalate, do **not** stop the run, and do **not** block this gate on it — record it as carried-forward and continue to QA handoff. This differs from every other Quality Gate item: a code-review or build failure that survives 3 iterations escalates to the user; a Sonar finding that survives 3 rounds is documented and carried forward instead.

7. Log MINOR/INFO, and any BLOCKER/CRITICAL/MAJOR still open after round 3, to `5_progress/PROJ-<X>-progress.md`.

---

## Execution and evidence

Use the existing lead to coordinate these commands; no additional scheduler is needed.

1. Source `scripts/env-local.sh`. Freeze a committed revision; allow no code edits while verification runs. Run the integration reviewer alongside build and coverage where resources permit. Keep shared DB/browser commands sequential and under their existing lock/auth controls.
2. Inspect `sonar_cmd` before starting. If its wrapper generates coverage, split it into a `coverage_cmd` and scanner-only `sonar_cmd`; keep the wrapper's ordinary combined entry point for other callers. Declare `coverage_artifacts` (for example `coverage/lcov.info`). Do not also declare the same coverage command as a quality-phase test. Coverage test failures block; never treat a successful upload of partial coverage as passing tests.
3. Run `node scripts/quality-evidence.mjs <X> <theme> run coverage` when configured. Only unchanged, successful coverage with intact artifacts is reusable. Then run Sonar; never run a scanner against coverage still being written. If no separate coverage command exists, execute the configured Sonar wrapper as-is without claiming coverage reuse.
4. Run each declared quality command with `node scripts/quality-evidence.mjs <X> <theme> run 'test:<label>'`, and lint with `... run lint` (`lint_cmd`, default `npm run lint`). These commands run live, require successful exits, and tests require positive selection. Auth-consuming quality entries execute their preflight and command under `worktree.sh with-shared-lock`. Retain CI/nightly workflow-wiring checks.
5. Collect reviewer, build, tests, lint and Sonar reports before editing. Batch confirmed findings into one recovery round; dispatch disjoint fixes concurrently, overlapping files serially. After integration/commit, run quality tests, lint, build and coverage once on that revision, re-review the fix diff, then submit one fresh Sonar scan. If no code changed, do not repeat successful commands merely because another stream reported later. Keep per-issue attempt history: non-Sonar blockers escalate after three fixes; Sonar retains its three-round carry-forward policy. An unrelated later review fix does not reset Sonar's budget; refresh analysis on the final revision without starting more Sonar fix rounds.
6. Save the completed review report in `5_progress/` and bind it with `node scripts/quality-evidence.mjs <X> <theme> review <report-path>` only after confirmed P0/P1 issues are resolved. For an allowed Sonar skip use `... skip-sonar 'sonar CLI unavailable'` or `... skip-sonar 'project not configured'`.
7. Update the human-readable statuses below, then run `bash scripts/quality-gate-proof.sh <X> <theme>`. It now requires command evidence as well as statuses: current inputs, exact configured command, exit result, unchanged log, positive test selection and output artifact hashes. Scanner submission also requires a fresh task receipt; the Sonar stream still fetches the completed task's server results and records its disposition before marking `Status: ran`.

Evidence is generated in `5_progress/quality-*.json` and logs. Each record retains the verified commit. Evidence-only commits do not invalidate the code proof; code/configuration changes do. Build and coverage reuse is opt-in through artifact lists, not a general cache for external services. Never hand-edit a proof record. Commands are bounded by their configured `<kind>_seconds` timeout (quality tests use `ac_seconds`, fallback 600 seconds).

---

## Exit Criteria

The quality gate passes when ALL of these are true:

- [ ] Every declared `quality` phase command passed once; CI/nightly commands are wired to their named workflows
- [ ] Zero P0/P1 code review findings remain
- [ ] Full PROJ build passes (`build_cmd` from `wave-gate-config.json`)
- [ ] If Sonar ran: zero BLOCKER/CRITICAL/MAJOR sonar issues, or every remaining one is documented as carried-forward after 3 fix rounds (a carried-forward Sonar issue does not block this gate)
- [ ] If Sonar was skipped: explicit skip reason is logged
- [ ] Declared integration/quality-phase tests still passing
- [ ] No new lint errors (`npm run lint`)

For every gate item except Sonar's fix loop: if it cannot pass after 3 fix iterations on the same issue, escalate to user. Sonar's own 3-round loop (Gate 3, step 6) never escalates or blocks — it documents and moves on.

---

## Progress Tracking

Update `5_progress/PROJ-<X>-progress.md` with a Quality Gate section after running:

```markdown
## Quality Gate — PROJ-X

### Code Review
Status: passed
Spec: 1 finding (worst: P1 AC-3 only partly implemented)
Standards: 2 findings (worst: P2 data clump)
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| P0 Critical | 0 | 0 | 0 |
| P1 High | 2 | 2 | 0 |
| P2 Medium | 1 | 0 | 1 |
| P3 Low | 3 | 0 | 3 |

### Build
Status: passed

### Tests
Status: passed

### Lint
Status: passed

### SonarCloud
Status: ran | skipped (sonar CLI unavailable) | skipped (project not configured)

| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| Critical | 0 | 0 | 0 |
| Major | 1 | 1 | 0 |
| Minor | 4 | 0 | 4 |
| Info | 2 | 0 | 2 |

### Fixed Issues
- P1: `src/features/foo/bar.ts:42` — Missing null check → fixed in abc123
- Major: `src/features/foo/baz.ts:10` — Cognitive complexity 19 → refactored in def456

### Deferred (user decision)
- P2: `src/features/foo/qux.ts:88` — Data clump, 3 params passed together
- Minor: `src/features/foo/utils.ts:15` — Prefer replaceAll over replace with regex

### Carried Forward (Sonar, 3 fix rounds exhausted)
- Major: `src/features/foo/legacy-parser.ts:120` — Cognitive complexity 24 (limit 15); round 3 refactor reduced it to 18, still over limit — needs a structural split, not a local fix
```
