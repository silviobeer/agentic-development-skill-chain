---
name: sonar-cli
description: Set up, run, troubleshoot, and triage SonarQube Cloud/Server analysis from Claude. Use when working with SonarScanner CLI (`sonar-scanner`), SonarQube CLI (`sonar`), SonarCloud project setup, quality gate creation/assignment/status, `sonar-project.properties`, `SONAR_TOKEN`, coverage import/LCOV merging, issue/security hotspot queries, scanner authentication failures, or confusion about which Sonar CLI to use.
---

# Sonar CLI

## Core Distinction

Use the two Sonar CLIs for different jobs:

- `sonar-scanner`: whole-project analysis upload. Use for CI, quality gates, coverage import, `sonar-project.properties`, and final source scans.
- `sonar`: developer/operator CLI. Use for `sonar auth status`, creating/listing projects, listing issues, calling Sonar APIs, scanning one file, and generating one-off tokens.

If the user is confused about the two tools, read `references/cli-distinction.md`.

## Project Setup Workflow

1. Inspect the repo before writing config:
   - package/build system: `package.json`, lockfiles, test runner config.
   - existing Sonar config: `rg --files -g 'sonar-project.properties' -g '.sonar*'`.
   - coverage output paths.
2. Create or update `sonar-project.properties` with stable project metadata:
   - `sonar.host.url`
   - `sonar.organization` for SonarQube Cloud
   - `sonar.projectKey`
   - `sonar.sources`
   - `sonar.tests`
   - language coverage path, such as `sonar.javascript.lcov.reportPaths=coverage/lcov.info`
3. Add `.scannerwork/` to `.gitignore`; coverage output should normally already be ignored.
4. Add local scripts only when they match the repo:
   - `test:coverage` should generate the report referenced by Sonar.
   - `sonar` can call `sonar-scanner`.
5. Run coverage before the scanner.
6. Run `sonar-scanner` with an analysis token, normally through `SONAR_TOKEN`, never committed.
7. Wait for the compute task, then pull issue and measure data through `sonar api` or `sonar list issues`.
8. Keep project measured state separate from quality gate status. Clean measures do not mean an enforced gate exists.

## Authentication Workflow

First check which CLI is authenticated:

```bash
sonar auth status
env | awk -F= '/^SONAR/ { print $1 }'
```

Important: a successful `sonar auth status` does not mean `sonar-scanner` is authenticated. The scanner generally needs `SONAR_TOKEN` or `-Dsonar.token=...`.

If `sonar` is authenticated and has permission, generate a short-lived scanner token without printing it:

```bash
TOKEN_JSON=$(sonar api post "/api/user_tokens/generate" --data "{\"name\":\"local-scanner-$(date +%Y%m%d%H%M%S)\"}")
SONAR_TOKEN=$(TOKEN_JSON="$TOKEN_JSON" node -e 'const data=JSON.parse(process.env.TOKEN_JSON); if (!data.token) process.exit(2); process.stdout.write(data.token);') sonar-scanner
```

If the organization from `sonar auth status` differs from `sonar.organization`, either log into the correct org/account or change the project config only if that matches the user's intent.

## Quality Gate Workflow

Measured project state and quality gate status are separate. A project can have clean measures while `/api/qualitygates/project_status` returns `NONE` because no gate is assigned or no new analysis has run since assignment.

Use this workflow when a project needs an enforced gate:

```bash
sonar api get "/api/qualitygates/list?organization=<org>"
sonar api post "/api/qualitygates/create" --data "name=<gate-name>&organization=<org>"
# or copy an existing gate:
sonar api post "/api/qualitygates/copy" --data "id=<source-gate-id>&name=<gate-name>&organization=<org>"
sonar api post "/api/qualitygates/create_condition" --data "gateName=<gate-name>&metric=coverage&op=LT&error=80&organization=<org>"
sonar api post "/api/qualitygates/select" --data "organization=<org>&projectKey=<project-key>&gateName=<gate-name>"
sonar-scanner
```

Gate assignment is not retroactive. After assigning or changing a gate, the previous analysis may still show `NONE`; run a fresh `sonar-scanner` analysis before expecting `project_status` to become `OK` or `ERROR`.

Always check both assignment and evaluated status:

```bash
sonar api get "/api/qualitygates/get_by_project?organization=<org>&project=<project-key>"
sonar api get "/api/qualitygates/project_status?projectKey=<project-key>"
```

Do not use `security_hotspots` directly as a quality-gate metric through `create_condition`; check hotspots separately:

```bash
sonar api get "/api/hotspots/search?projectKey=<project-key>&ps=500"
```

## Triage Workflow

After a successful scan:

```bash
sonar api get "/api/ce/task?id=<task-id>"
sonar list issues --project <project-key> --page-size 500
sonar api get "/api/measures/component?component=<project-key>&metricKeys=bugs,vulnerabilities,code_smells,security_hotspots,coverage,duplicated_lines_density,ncloc"
sonar api get "/api/qualitygates/project_status?projectKey=<project-key>"
```

Prioritize fixes in this order:

1. Real bugs and vulnerabilities.
2. Security hotspots with actual exploitability.
3. Accessibility issues that affect users.
4. Cognitive-complexity and readability issues in recently touched files.
5. Mechanical style issues only when they are low-risk and broad enough to justify churn.

Use `NOSONAR` sparingly and only with a precise inline reason when the finding is a confirmed false positive or an intentional local-only prototype artifact.

## Coverage Workflow

Sonar's `coverage` metric combines line and branch/condition coverage. An LCOV line coverage value such as 85% can become Sonar coverage around 79.3% if branch/condition coverage is lower.

Use coverage exclusions sparingly. Exclude boundary wrappers only when justified, such as:

- Next.js `page`/`layout` wrappers.
- Server-action wrappers with no domain logic.
- Generated Supabase types.
- Supabase client factories.

Keep domain logic, repositories, services, validation, and UI components in coverage scope.

For repos with separate unit and DB Jest configs, merge LCOV before scanning:

```bash
rm -rf coverage
npm run test:unit -- --coverage --coverageDirectory=coverage/unit
npm run test:db -- --coverage --coverageDirectory=coverage/db
npx lcov-result-merger "coverage/**/lcov.info" "coverage/lcov.info"
sonar-scanner
```

If the repo uses different scripts or reporters, preserve the same shape: produce one merged `coverage/lcov.info`, point `sonar.javascript.lcov.reportPaths` at it, then scan.

## Final Verification Bundle

Run this bundle before declaring Sonar clean:

```bash
sonar api get "/api/issues/search?componentKeys=<project-key>&resolved=false&ps=500"
sonar api get "/api/hotspots/search?projectKey=<project-key>&ps=500"
sonar api get "/api/measures/component?component=<project-key>&metricKeys=bugs,vulnerabilities,code_smells,security_hotspots,coverage"
sonar api get "/api/qualitygates/project_status?projectKey=<project-key>"
```

## Common Failure Modes

- `sonar.organization` missing: SonarQube Cloud scanner config is incomplete.
- `Project not found`: wrong `sonar.projectKey`, wrong `sonar.organization`, missing project, or token lacks access.
- Scanner 403 while `sonar auth status` is connected: the scanner is not using the `sonar` CLI login token; pass `SONAR_TOKEN`.
- Coverage warning about unresolved paths: LCOV references files outside indexed `sonar.sources`/`sonar.tests`, or test helper files are not included in `sonar.test.inclusions`.
- Missing blame warnings are expected with dirty/uncommitted files and do not necessarily affect quality gate conditions.
- Quality gate status remains `NONE` after assignment: run a fresh `sonar-scanner`; gate assignment is not retroactive.

## Official References

- SonarScanner CLI: https://docs.sonarsource.com/sonarqube-cloud/analyzing-source-code/scanners/sonarscanner-cli
- SonarQube CLI command reference: https://docs.sonarsource.com/sonarqube-developer-tools/sonarqube-cli/using-sonarqube-cli/commands
- Sonar Web API: https://docs.sonarsource.com/sonarqube-server/extension-guide/web-api
