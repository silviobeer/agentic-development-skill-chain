---
name: bugfixing
description: "Reproduce, diagnose, plan, implement, and verify reported software bugs, regressions, broken UI flows, incorrect behavior, and production defects. Use whenever a user asks to fix a bug or regression, investigate why behavior is wrong, or explain why existing tests missed a defect. Reproduce browser-facing bugs in a real browser when safe and available, prove the regression test fails before the fix, dispatch a narrowly scoped implementer, run a bounded Ralph verification loop, and document the test-escape cause. Not for feature requests, speculative refactors, or QA-only discovery without a requested fix."
---

# Bugfixing

Fix one reported defect from evidence to verified prevention. A successful run
does more than make the symptom disappear: it reproduces the failure, identifies
the code cause and the test-system escape, adds or repairs a regression test that
would have caught it, applies the smallest safe fix, and re-verifies the original
user path.

This is an optional workflow outside the numbered 0-to-8 feature chain. Do not
create a PROJ, PRD, architecture document, or wave plan for an ordinary bugfix.

## Mandatory Delegation Contract

When subagents are available and permitted, workers own all product-source,
regression-test, defect-fix, and human-documentation edits. The lead owns
decomposition, dispatch, integration, deterministic verification, gates, and
operational records. Dispatch independent tasks with disjoint file ownership in
parallel; serialize dependent or overlapping work. Send integration corrections
to a follow-up worker. The lead may edit covered files locally only when
delegation is unavailable or prohibited, and must report the reason explicitly.

## Reuse The Existing Chain

Reuse the repository's established machinery rather than defining parallel
versions:

- Reuse `5_executing`'s deterministic evidence principles: actual commands,
  verbatim failures, and positive controls. This skill retains its own cap of
  at most three repair attempts.
- Dispatch one `micro-fixer` from `4b_setup/manifests/roles/micro-fixer.md` for
  the implementation when delegation is available and permitted. If delegation
  is unavailable or prohibited, report why, apply the same narrow prompt, and
  implement locally.
- Follow `6_qa`'s browser procedure for UI reproduction and final verification.
- Reuse the existing `.coderabbit.yaml` or `.coderabbit.yml` and the CodeRabbit
  review conventions from `5_executing`.
- Use the optional `sonar-cli` skill only when the project is already configured
  for Sonar and both CLIs are available.
- In a framework PROJ, write findings only through `scripts/ledger.mjs` and read
  or change machine state only through `scripts/state.sh`. Never edit
  `state.json` or `findings.json` directly.

Do not invoke full `executing` or full `qa` for a standalone one-bug repair. They
own larger feature waves and release QA; this skill borrows their proven checks.

## Working Modes

### Standalone bugfix

Use this mode when no matching active framework PROJ exists. Create one run
folder:

```text
specs/_bugfixing/BUGFIX-YYYYMMDD-HHMM-<slug>/
├── bugfix-report.md
└── evidence/                  # only when screenshots, traces, or concise logs exist
```

Copy `references/bugfix-report.md.tmpl` into `bugfix-report.md` and update it as
the run progresses. Keep raw noisy logs out of the report; link to evidence or
quote only the decisive lines.

### Framework-owned bug

Use this mode only when the report clearly belongs to an existing
`specs/PROJ-<X>-<theme>/` and its framework files are present.

- Record a confirmed defect as one JSON line through:

  ```bash
  node scripts/ledger.mjs add <X> <theme>
  ```

  Use `source: "qa"` for reproduced behavioral defects and include a stable file
  plus symbol anchor when known.
- Reuse the PROJ progress file for human-readable evidence; do not create a
  second fix queue.
- If an autonomous P6 runner is active, stop after evidence and ledger intake.
  Its P6 controller owns triage, attempt counting, micro-fixer dispatch, status
  updates, and fresh re-verification.
- If the user explicitly started an interactive fix and no runner owns the
  PROJ, use the same workflow below, dispatch `micro-fixer`, and update finding
  status only with `ledger.mjs` after fresh verification.
- Re-run the existing wave or quality gate when the bug belongs to an unsealed
  wave. Do not invent a synthetic wave merely to use `wave-gate.sh`.

This skill never transitions framework phase state.

## Workflow

### 1. Establish a safe baseline

Read `AGENTS.md`, the repository status, relevant project documentation, and the
bug report before editing anything. Record the starting commit and preserve
unrelated user changes.

Separate an ordinary repair from incident mitigation. A request to fix code does
not authorize production deployment, rollback, destructive data repair, or
probing an external system with unsafe inputs. Reproduce against local or staging
state whenever possible. For security-sensitive defects, minimize stored secrets
and exploit detail.

### 2. Normalize the report

Extract what is already known instead of interviewing the user again:

- concise symptom and user impact;
- expected and actual behavior;
- exact reproduction steps;
- environment: version/commit, browser or client, OS, viewport, account role,
  feature flags, locale/timezone, and relevant data state;
- screenshots, traces, console/network output, logs, or stack traces;
- first known occurrence and whether it is a regression.

Ask only for information that cannot be discovered locally and materially blocks
safe reproduction. Do not guess credentials, production data, or intended
behavior.

### 3. Reproduce before proposing a fix

For browser-facing reports, start the application using its documented command
and reproduce the exact user flow in a real browser. Capture the smallest useful
evidence: final screenshot plus a trace, console excerpt, or failed network
request when it explains the defect. Record browser, viewport, route, test data,
and account role.

For API, worker, CLI, data, or build defects, use the narrowest deterministic
command or request that demonstrates expected versus actual behavior. Do not
force a browser onto a non-browser bug.

Classify the outcome explicitly:

- `reproduced` — the observed failure matches the report;
- `different-failure` — a failure exists, but it is not the reported one;
- `not-reproduced` — the documented conditions were exercised without failure;
- `blocked` — credentials, environment, data, tooling, or safety constraints
  prevent a meaningful attempt.

Do not change production code for `different-failure`, `not-reproduced`, or
`blocked` reports. Record attempts, evidence, and the smallest next step that
would distinguish the leading hypotheses. A different observed failure is a
separate bug unless the user authorizes it. Instrumentation is a separate
proposed change, not a guessed fix.

For a UI bug, absence of real-browser verification is a release gap. If browser
automation is unavailable, report the degraded result and do not claim the bug is
fully verified unless the user explicitly accepts that gap.

### 4. Trace the code cause and test escape

Follow the reproduced path from the user-visible failure into the smallest
responsible code boundary. Distinguish:

- **trigger:** the input, state, timing, environment, or sequence that exposes the
  defect;
- **code cause:** the incorrect logic or contract that produces it;
- **test escape:** the property of the test system that allowed the code cause to
  ship.

Inspect existing tests before writing the plan. Run the nearest relevant tests
unchanged and read their assertions, fixtures, mocks, environment, and selection
rules. When the report asks why CI missed the defect, inspect the actual workflow,
test command, filters, and available historical result rather than inferring CI
coverage from local filenames. Classify the primary escape as one of:

1. `missing-coverage` — no test exercised the behavior;
2. `wrong-layer` — coverage existed, but not at the boundary where behavior broke;
3. `weak-oracle` — the test ran the path but asserted too little or the wrong result;
4. `unrepresentative-fixture` — data, permissions, flags, locale, viewport, or
   timing omitted the trigger;
5. `mock-bypass` — a mock replaced the faulty integration or behavior;
6. `not-selected` — the relevant test was disabled, quarantined, misnamed, or not
   run by CI;
7. `flaky-or-racy` — nondeterminism hid the failure;
8. `changed-contract` — intended behavior changed without updating the test
   contract.

Name one primary escape and any contributing escapes. Avoid blaming a person;
describe the missing or ineffective system guard.

### 5. Write the executable fix plan

Before implementation, update the report with:

- confirmed reproduction and evidence;
- trigger, code-cause hypothesis, and confidence;
- primary test-escape classification with evidence;
- files or boundaries expected to change;
- the smallest behavior-preserving fix;
- regression-test location and layer;
- deterministic acceptance checks and exact commands;
- explicit non-goals, especially nearby refactors;
- rollback or compatibility concern when relevant.

Once the reported defect is reproduced, the user has authorized its
implementation by asking for a fix. Do not add a separate approval pause unless
the plan reveals a materially broader change, data migration, public contract
decision, or risky external action.

### 6. Prove the regression test is red

Add or repair the smallest test at the lowest layer that reliably captures the
defect, while preserving a real-browser test when the failure only appears in the
assembled UI.

Run the regression test before changing production code and record:

- exact command;
- non-zero result and selected-test count;
- assertion or failure line that corresponds to the reproduced symptom.

A test that fails for setup errors, unrelated assertions, or because zero tests
were selected is not red proof. Include a positive control when a silent no-op,
authorization failure, polling matcher, or missing fixture could create a false
positive.

If an emergency fix necessarily preceded the test, prove the test against the
pre-fix code in a throwaway worktree based on the recorded start commit. Never
temporarily damage the user's working tree to manufacture red evidence.

### 7. Dispatch the narrow fix

Give the implementer or `micro-fixer` only:

- the reproduced finding and user impact;
- trigger and current code-cause hypothesis;
- the red regression-test command and verbatim failure;
- allowed files or subsystem boundary;
- acceptance checks;
- explicit instruction to avoid unrelated refactors and dependency additions.

The implementer fixes one defect, runs the targeted test, and returns the changed
files plus command output. The orchestrator remains responsible for independent
verification.

### 8. Run the bounded Ralph loop

Immediately after implementation, verify every fix-plan acceptance criterion:

```text
while any criterion fails and attempts < 3:
  run every deterministic check
  preserve the exact failure output
  dispatch one narrowly scoped correction
  re-run every criterion, including previously green checks
```

Required criteria:

1. the regression test passes and selects at least one test;
2. the nearest relevant existing tests pass;
3. the original reproduction no longer fails;
4. when silent failure or inactive setup could produce a false green, a positive
   control proves the tested path is active;
5. no acceptance criterion relies only on code inspection.

The original implementation dispatch is attempt 1; each correction dispatch is
the next attempt. After attempt 3 fails the same criterion, stop and report the
exact remaining failure and all attempts. Do not broaden the patch by guesswork.

### 9. Run proportionate quality gates

Run once after the Ralph criteria are green:

- relevant test suite, then full suite when its cost is reasonable;
- lint/typecheck/build commands affected by the change;
- one initial CodeRabbit review against the recorded start commit when the CLI
  and repository configuration are available. If it requests changes, fix
  blocking findings, re-run every Ralph criterion, then run CodeRabbit again only
  on the review-fix diff;
- Sonar only when `sonar`, `sonar-scanner`, and project configuration already
  exist. Follow `sonar-cli`; do not create Sonar infrastructure just for a
  routine bugfix.

In a framework wave, the existing wave gate owns build, CodeRabbit, and smoke
checks; run it instead of duplicating those commands. Record unavailable
standalone tools as explicit skips. A Sonar skip is non-blocking. A missing
browser remains a verification gap for browser-facing bugs.

### 10. Close the learning loop

Complete the report with:

- final root cause and trigger;
- code change summary;
- red and green regression-test proof;
- original-path verification evidence;
- why the bug passed the previous test system;
- which test or process guard now prevents recurrence;
- CodeRabbit and Sonar dispositions;
- remaining risks and skipped checks;
- one concise `AGENTS.md` candidate only when the lesson is repeatable,
  project-wide, and expressible as a short rule.

Do not edit the root `AGENTS.md` directly. Hand the candidate to the user or the
documentation skill for approval.

## Completion Gate

Declare the bug fixed only when all are true:

- reproduction is confirmed and the same path is green after the change;
- trigger and code cause are supported by evidence;
- the regression test demonstrably failed before the fix and passes after it;
- the primary test escape is named and corrected or consciously mitigated;
- Ralph acceptance checks are green within three attempts;
- proportionate suites and static gates pass, with explicit skips recorded;
- unrelated user changes remain untouched;
- the report is complete and contains no unsupported claims.

If any item is missing, report `partially verified`, `not reproduced`, or
`blocked` instead of `fixed`.
