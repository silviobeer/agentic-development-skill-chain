# Sonar CLI Distinction

## Decision Table

| Need | Use | Why |
| --- | --- | --- |
| Upload full project analysis | `sonar-scanner` | It reads `sonar-project.properties`, analyzes source, imports coverage, uploads a report, and creates a compute-engine task. |
| CI pipeline scan | `sonar-scanner` | CI should use an explicit analysis token and deterministic config. |
| Check authenticated account/org | `sonar auth status` | The developer CLI owns its login state. |
| List projects or issues | `sonar list projects`, `sonar list issues` | The developer CLI returns API data in terminal-friendly formats. |
| Call Sonar APIs | `sonar api <method> <endpoint>` | Useful for project creation, compute-task polling, measures, and token generation. |
| Scan one local file interactively | `sonar verify --file <file>` | File-level developer feedback; not a substitute for project analysis. |

## Mental Model

`sonar-scanner` is the build/analysis uploader.

`sonar` is the operator console.

They may point at the same SonarCloud/SonarQube instance, but their authentication flows are separate in practice. Do not assume the scanner can use the `sonar` CLI's stored login. Prefer `SONAR_TOKEN` for scanner runs.

## Minimal TypeScript/Next Pattern

```properties
sonar.host.url=https://sonarcloud.io
sonar.organization=<org-key>
sonar.projectKey=<org-or-owner>_<repo-or-project>
sonar.projectName=<display name>

sonar.sources=src
sonar.tests=tests
sonar.sourceEncoding=UTF-8

sonar.exclusions=src/lib/supabase/types.ts
sonar.test.inclusions=tests/**/*.test.ts,tests/**/*.test.tsx,tests/**/*.dbtest.ts
sonar.javascript.lcov.reportPaths=coverage/lcov.info
```

## Token Handling

Never commit a token to source control.

Use one of:

```bash
SONAR_TOKEN=... sonar-scanner
sonar-scanner -Dsonar.token=...
```

If an authenticated `sonar` CLI session is available, it can generate a user token through the Web API. Avoid printing the token; pipe it into the scanner environment for that process only.

## Issue Triage Pattern

Use the scanner to publish analysis, wait for the compute task, then use `sonar` to inspect the result:

```bash
sonar api get "/api/ce/task?id=<task-id>"
sonar list issues --project <project-key> --page-size 500
sonar api get "/api/measures/component?component=<project-key>&metricKeys=bugs,vulnerabilities,code_smells,security_hotspots,coverage"
```

Fix bugs/vulnerabilities first. Treat hotspots as review items: either fix them or mark them reviewed in Sonar only when the rationale is real.
