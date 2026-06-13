# Quality Gate

Runs once per PROJ-X after all waves complete and all ACs are verified.
Must pass before handing off to QA.

## Prerequisites

- All waves complete, all ACs verified by outer Ralph loop
- Record `BASE_SHA` (commit before first implementation change) at the start of execution

---

## Gate 1: Code Review Expert

Full review of the entire feature diff — catches cross-cutting issues the per-US inner Ralph loop may miss.

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
   - Spawn fix subagent per issue (or batch related issues)
   - Re-run all tests after fixes
   - Re-review the fix diff to ensure no regressions

5. Log P2/P3 to `7_progress/PROJ-<X>-progress.md` under the Quality Gate section.

---

## Gate 2: PROJ-End Build

Run the full project build once after all waves have passed:

```bash
# Use build_cmd from specs/PROJ-<X>-<theme>/6_plan/wave-gate-config.json
npm run build
```

If the build fails, fix it with the verbatim compiler output and rerun the build before Sonar/QA. This is the PROJ-level build check; do not add extra builds between individual implementation tasks.

---

## Gate 3: Optional Sonar Scan

Fetch fresh SonarQube Cloud/Server issues for files touched by this feature when both Sonar CLIs are available.

### Preflight

```bash
command -v sonar >/dev/null && command -v sonar-scanner >/dev/null
```

- If both commands exist, run this gate using the `sonar-cli` skill guidance.
- If either command is missing, skip this gate and record `SonarCloud: skipped (sonar CLI unavailable)` in `7_progress/PROJ-<X>-progress.md`.
- If both commands exist but the project has no Sonar config and no explicit user/plan requirement to create one, skip this gate and record `SonarCloud: skipped (project not configured)`.
- A skipped Sonar gate does not block QA handoff.

### Steps

1. Get the list of files changed by this feature:
   ```bash
   git diff BASE_SHA..HEAD --name-only
   ```

2. Run the Sonar scanner to upload the latest code for analysis:
   ```bash
   sonar-scanner
   ```
   If the repo provides a matching script such as `npm run sonar` that runs coverage first and then `sonar-scanner`, use that script instead. Wait for the scan to complete before proceeding.

3. Fetch current Sonar issues, measures, and quality-gate status:
   ```bash
   BRANCH=$(git rev-parse --abbrev-ref HEAD)
   sonar list issues --project <project-key> --branch "$BRANCH" --page-size 500
   sonar api get "/api/measures/component?component=<project-key>&metricKeys=bugs,vulnerabilities,code_smells,security_hotspots,coverage,duplicated_lines_density,ncloc"
   sonar api get "/api/qualitygates/project_status?projectKey=<project-key>"
   ```

4. Filter issues to only files from step 1.

5. Classify by SonarCloud severity:
   - **BLOCKER / CRITICAL** → must fix
   - **MAJOR** → must fix (treat as P1)
   - **MINOR** → log for user decision
   - **INFO** → log only

6. Fix all BLOCKER/CRITICAL/MAJOR:
   - Spawn fix subagent with the sonar issue details (file, line, message, rule)
   - Re-run tests after fixes
   - Update `scripts/sonar-tracker.md` if it exists (mark fixed items `[x]`)

7. Log MINOR/INFO to `7_progress/PROJ-<X>-progress.md`.

---

## Exit Criteria

The quality gate passes when ALL of these are true:

- [ ] Zero P0/P1 code review findings remain
- [ ] Full PROJ build passes (`build_cmd` from `wave-gate-config.json`)
- [ ] If Sonar ran: zero BLOCKER/CRITICAL/MAJOR sonar issues in feature files
- [ ] If Sonar was skipped: explicit skip reason is logged
- [ ] All tests still passing (`npm run test`)
- [ ] No new lint errors (`npm run lint`)

If the gate cannot pass after 3 fix iterations on the same issue, escalate to user.

---

## Progress Tracking

Update `7_progress/PROJ-<X>-progress.md` with a Quality Gate section after running:

```markdown
## Quality Gate — PROJ-X

### Code Review
| Severity | Found | Fixed | Deferred |
|----------|:-----:|:-----:|:--------:|
| P0 Critical | 0 | 0 | 0 |
| P1 High | 2 | 2 | 0 |
| P2 Medium | 1 | 0 | 1 |
| P3 Low | 3 | 0 | 3 |

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
```
