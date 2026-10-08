# wave-gate-config.json

Feeds `wave-gate.sh` (Skill 5); its commands are the ones Ralph runs. Structure
is enforced by `validate-wave-plan.mjs` — write from the example, run the
validator, fix what it reports. This file covers only what it cannot check.

```json
{
  "build_cmd": "npm run build",
  "sonar_cmd": "npm run sonar",
  "timeouts": { "ac_seconds": 300, "ralph_stall_seconds": 300, "build_seconds": 600, "coderabbit_seconds": 600, "browser_seconds": 120 },
  "auth_provider_rate_limited": true,
  "auth_budget": { "preflight_cmd": "npm run auth:budget-check", "rate_limit_evidence_cmd": "npm run auth:rate-limit-check", "exhausted_exit_code": 75 },
  "frontend": {
    "dev_cmd": "npm run dev",
    "dev_url": "http://localhost:3000",
    "readiness": { "path": "/health", "timeout_seconds": 60, "interval_seconds": 2 },
    "routes": [{ "wave": "2", "path": "/account", "expected_url": "http://localhost:3000/account", "expected_text": "Your account", "protected": true, "auth_state": "tests/e2e/.auth/user.json" }]
  },
  "phase_commands": [{ "label": "hosted browser auth regression", "phase": "nightly", "command": "npm run test:e2e -- tests/e2e/auth.spec.ts", "test_files": ["tests/e2e/auth.spec.ts"], "auth_consuming": true, "workflow_file": ".github/workflows/e2e.yml" }],
  "waves": {
    "1": {
      "codex_effort": "high",
      "advisory_severities": ["medium", "low"],
      "ac_commands": [{ "id": "PROJ-1-PRD-1-US-1-AC-1", "task": "Task PROJ-1-PRD-1-US-1-T1", "command": "npm test -- src/auth/password.test.ts", "test_files": ["src/auth/password.test.ts"], "auth_consuming": false }],
      "regression_commands": [{ "label": "auth regression suite", "command": "npm test -- src/auth", "test_files": ["src/auth/password.test.ts", "src/auth/session.test.ts"], "auth_consuming": false, "require_non_empty_selection": true }]
    }
  }
}
```

Optional top-level keys: `lint_cmd` (default `npm run lint`), `build_artifacts` (final-wave build reuse, deterministic builds only), `coverage_cmd` + `coverage_artifacts` (split coverage out of a Sonar wrapper; `sonar_cmd` then stays scanner-only). `sonar_cmd` is the repo's real entry point, run once at the PROJ-end Quality Gate. All five `timeouts` keys are required — the gate (not the validator) fails without them.

## Judgment rules

- **AC commands:** cheapest deterministic proof of the new behaviour. Output must print a selected-test count (`Running N tests`, `Tests N passed`, `# tests N`, `N passed`) — zero/unparseable blocks. Auth-consuming only when the story changes auth or nothing cheaper proves it.
- **Regressions:** smallest suite covering shared behaviour the wave actually touches — not a replay of prior ACs, auth suites, or the E2E inventory. `require_non_empty_selection: true` for runners that can silently select nothing. `reuse_passed: true` only for deterministic local suites, never browser or external-DB checks. Filtered browser suites add a read-only `selection_check_cmd` using the same selector, listing tests without browser/DB/auth.
- **Phase commands:** full hosted-auth and Playwright suites go here (`quality` runs once after all waves; `ci`/`nightly` name the workflow running that exact command). Deferral never replaces the wave's own AC proof.
- **Auth hooks:** `preflight_cmd` exits `exhausted_exit_code` (75) when the budget is gone. `rate_limit_evidence_cmd` runs after a failed auth-consuming command and checks provider/server state outside the test log: `0` + decisive evidence = rate-limited, `1` = not, other = infra failure; gets `WAVE`, `WAVE_GATE_CONFIG`, `RALPH_STATE`, `AC_ID`, `AC_LOG`. With `SKILLCHAIN_AUTH_BUDGET_NEGATIVE_CONTROL=1`, preflight reports exhaustion without consuming an identity and the evidence hook exits 0 with simulated evidence.
- **Routes:** `authenticated_e2e_test_files` (instead of `auth_state`) only if that scenario really verifies the route. A redirect to login is never smoke success. Omit `frontend` for backend-only PROJs.
- **`advisory_severities`** (non-blocking CodeRabbit levels): `["medium","low"]` normally; add `high` only for low-risk polish/doc/test waves; never `critical`/`blocker`/`error` without explicit user acceptance. **`codex_effort`:** default `high`, `medium` for polish waves.
- **`external_dependency`** on an AC awaiting a named external approval (`reason`, `decided_by`, `decided_at`, `check_command`): record the real decision in `decisions.md`, never invent it. The read-only checker returns 0 = approved, 76 = absent. The gate marks the AC `blocked_external` and returns 76 without certifying the wave or unlocking dependents. To continue independent work, replan dependencies; never descope the AC.
- **Browser files:** one scenario file per wave or cohesive feature with a named owner (e.g. `tests/e2e/wave-<N>.test.mjs`); keep wave fixture cleanup with its scenarios; use the project's runner (`node --test` only without inherited lock descriptors). Don't split existing suites automatically: a deliberate split updates task/config/route mappings together, invalidates cached evidence, and keeps old certificates as historical proof only.
- **Legacy string `ac_commands`:** convert by hand (regression and auth choices need judgment), re-validate, get approval again.
