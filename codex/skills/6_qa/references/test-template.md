## QA Test Results

**Tested:** YYYY-MM-DD
**Tester:** QA Engineer (AI)

### Acceptance Criteria Status

#### AC-1: [Name]
- [x] Sub-criterion passed
- [ ] BUG: Sub-criterion failed (description)

#### AC-2: [Name]
- [x] Sub-criterion passed

### Edge Cases Status

#### EC-1: [Description]
- [x] Handled correctly
- [ ] BUG: Not handled (description)

### Security Audit Results

- [x] Authentication tested
- [x] Authorization tested
- [x] Input injection tested
- [x] Sensitive data exposure checked
- [ ] BUG: [security issue if any]

### Simplicity Gate Results

- **Files/modules inspected:** [diff scope]
- **Release-blocking complexity:** Yes / No
- [x] No unnecessary abstractions, duplicate primitives, speculative options, or dead paths found
- [ ] BUG: [simplicity issue if any]
- **Simplification notes:** [delete / inline / merge / reuse existing primitive / collapse state / remove option]

### Bugs Found

#### BUG-PROJ<X>-QA-001: [Title]
- **Severity:** Critical / High / Medium / Low
- **File:** `path/to/file.ts`
- **Anchor:** `export function foo` (symbol or regex — not a line number; survives parallel edits)
- **Source:** [persona / red-team / ui-audit / Playwright or agent-browser stream]
- **Status:** open | in-progress | fixed | accepted
- **Fix attempts:** 0
- **Steps to Reproduce:**
  1. Step 1
  2. Step 2
- **Expected:** What should happen
- **Actual:** What actually happens
- **Priority:** Fix before release / Fix in next sprint / Backlog

IDs are sequential within this QA run, zero-padded to 3 digits. They are the reference handle for fixer-spawns.

### Summary

- **Acceptance Criteria:** X/Y passed
- **Bugs Found:** N total (C critical, H high, M medium, L low)
- **Security:** Pass / Issues found
- **Simplicity Gate:** Pass / Issues found
- **Production Ready:** YES / NO
- **Recommendation:** [Deploy / Fix bugs first / Needs rework]

### AGENTS.md Candidates (for Skill 7 review)

Leave empty if no candidates. Otherwise:

- [ ] <proposed one-liner> — **why:** <one-sentence rationale pointing to BUG/source>
