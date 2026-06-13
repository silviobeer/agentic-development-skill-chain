---
name: sonar-cli
description: Set up, run, troubleshoot, and triage SonarQube Cloud/Server analysis from Claude. Use when working with SonarScanner CLI (`sonar-scanner`), SonarQube CLI (`sonar`), SonarCloud project setup, `sonar-project.properties`, `SONAR_TOKEN`, quality gate/issue queries, scanner authentication failures, or confusion about which Sonar CLI to use.
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

## Common Failure Modes

- `sonar.organization` missing: SonarQube Cloud scanner config is incomplete.
- `Project not found`: wrong `sonar.projectKey`, wrong `sonar.organization`, missing project, or token lacks access.
- Scanner 403 while `sonar auth status` is connected: the scanner is not using the `sonar` CLI login token; pass `SONAR_TOKEN`.
- Coverage warning about unresolved paths: LCOV references files outside indexed `sonar.sources`/`sonar.tests`, or test helper files are not included in `sonar.test.inclusions`.
- Missing blame for changed files: local uncommitted files or SCM state; not usually a blocker for local triage.

## Official References

- SonarScanner CLI: https://docs.sonarsource.com/sonarqube-cloud/analyzing-source-code/scanners/sonarscanner-cli
- SonarQube CLI command reference: https://docs.sonarsource.com/sonarqube-developer-tools/sonarqube-cli/using-sonarqube-cli/commands
- Sonar Web API: https://docs.sonarsource.com/sonarqube-server/extension-guide/web-api
