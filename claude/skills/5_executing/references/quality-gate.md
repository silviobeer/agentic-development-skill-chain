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

Full review of the entire feature diff — catches cross-wave integration issues that story-scoped implementation tests may miss. Do not replay wave ACs here.

### Steps

1. Get the feature diff:
   ```bash
   git diff BASE_SHA..HEAD --stat    # scope overview
   git diff BASE_SHA..HEAD           # full diff
   ```

2. Review using the full checklist from `references/code-reviewer.md`:
   - Architecture & SOLID
   - Security & Reliability
   - Error Handling
   - Performance
   - Boundary Conditions
   - Testing
   - Holistic "What Would I Do Better?"

3. Classify findings by severity:
   - **P0 Critical** — Security vulnerability, data loss risk, correctness bug → must fix
   - **P1 High** — Logic error, significant SOLID violation, performance regression → must fix
   - **P2 Medium** — Code smell, maintainability concern → log for user decision
   - **P3 Low** — Style, naming, minor suggestion → log only

4. Fix all P0/P1:
   - Spawn a fix subagent per issue (or batch related issues); run disjoint fixes concurrently and overlapping fixes serially
   - Re-run declared integration/quality-phase tests after fixes
   - Re-review the fix diff to ensure no regressions

5. Log P2/P3 to `5_progress/PROJ-<X>-progress.md` under the Quality Gate section.

---

## Gate 2: PROJ-End Build

Run `build_cmd` from `wave-gate-config.json` once for the assembled PROJ. If it fails, dispatch a fix worker with the verbatim compiler output and rerun the build. Do not add builds between individual implementation tasks.

---

## Gate 3: Sonar Scan (once per PROJ)

This is the only Sonar run in the whole PROJ — no wave gate runs Sonar.
`sonar_cmd`'s scanner submission already covers the full project, so by
definition this single run analyzes every wave's cumulative changes.

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
   bash -c "$SONAR_CMD"
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

6. Fix BLOCKER/CRITICAL/MAJOR in a bounded loop, up to 3 rounds:
   ```
   for fix_round in 1..3:
     if no BLOCKER/CRITICAL/MAJOR remain: break
     spawn fix subagent(s) with the sonar issue details (file, line, message, rule);
       cluster disjoint files concurrently, serialize overlapping files
     re-run declared integration/quality-phase tests after fixes
     re-run sonar_cmd (step 1) and re-fetch + re-classify issues (steps 2-5)
   ```
   - Each round's scan must independently satisfy step 2's no-silent-no-op check — a round that produces no fresh `.scannerwork/report-task.txt` did not run and cannot count toward the 3.
   - Update `scripts/sonar-tracker.md` if it exists (mark fixed items `[x]`) after every round.
   - **If BLOCKER/CRITICAL/MAJOR issues remain after round 3:** document each one in `5_progress/PROJ-<X>-progress.md` (file, line, rule, severity, what the last fix attempt changed and why the issue persisted). Do **not** escalate, do **not** stop the run, and do **not** block this gate on it — record it as carried-forward and continue to QA handoff. This differs from every other Quality Gate item: a code-review or build failure that survives 3 iterations escalates to the user; a Sonar finding that survives 3 rounds is documented and carried forward instead.

7. Log MINOR/INFO, and any BLOCKER/CRITICAL/MAJOR still open after round 3, to `5_progress/PROJ-<X>-progress.md`.

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
