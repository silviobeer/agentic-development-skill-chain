---
name: intake
description: "Bootstrap the curated context baseline for a brownfield (or near-greenfield) repo: scan the code and draft ALL curated docs with per-statement provenance markers, interview the developer through every gap/assumption/inconsistency, reconcile via the checkpoint loop, then seal as the initial curation baseline commit. Use when: (1) a repo has code but no curated docs/ baseline (docs/PRODUCT.md missing), (2) an explicit drift audit of the curated docs is requested, (3) a near-greenfield project needs its baseline before the first PROJ. Not for: per-PROJ documentation (use documentation), ongoing doc updates (P7 curation owns those), plan approval (use checkpoint)."
---

# Intake — Bootstrap the Curated Context Baseline

Owns the brownfield bootstrap of the agent workflow (CONCEPT.md §3).
Produces the ONE curated docs baseline that every later phase injects
into implementers — as early as possible, while the codebase is small
and the interview is cheap. After the seal, P7 curation owns ALL
updates; this skill is re-run only as a deliberate drift audit, never
automatically.

**The core principle: extraction and interview are two different
sources, and this skill needs both.** Code tells what IS. Only the
developer tells what is INTENDED — product scope and non-goals, security
requirements, which of two inconsistent conventions is the rule going
forward. This is a collaborative session, not a batch job.

## Output (the baseline — all eight files)

| File | Content | Cap |
|---|---|---|
| `docs/PRODUCT.md` | what the product is, for whom, non-goals | ½ page (≤30 non-blank lines) |
| `docs/ARCHITECTURE.md` | the load-bearing architecture truths; details → `docs/architecture/` | ≤200 lines |
| `docs/GUIDELINES.md` | conventions that ARE the rule (incl. Known Debt notes for losing patterns) | — |
| `docs/DESIGN-SYSTEM.md` | design **rules** extracted from code — tokens, scales, patterns, do/don't — or a pointer to **frontend-design** (1c) if none exist; never invented. No component inventory (that's `components.md`) | ≤80 lines |
| `docs/components.md` | component registry — **generated** by `scripts/gen-component-registry.mjs` from the doc block above each component export | — |
| `docs/security-baseline.md` | auth model, secret handling, input validation floor | — |
| `docs/test-conventions.md` | test runner, layout, naming, what must be tested | — |
| `AGENTS.md` (root) | initial durable agent rules | ≤40 non-blank lines |

**Existing AGENTS.md (or other curated docs) are baseline truth, never
overwritten.** If a file already exists, the draft is a MERGE: every
existing rule/statement is kept unless an interview decision explicitly
retires it (recorded in `decisions.md`); new content is appended with
provenance markers like everything else. The drift-audit variant works
the same way — deltas, not rewrites.

## Workflow

### 0. Precondition

- No curated baseline yet (`docs/PRODUCT.md` missing), OR the user
  explicitly asked for a drift audit of the existing baseline.
- Working space: `specs/intake/` (drafts + decision log). This is
  pre-PROJ — there is **NO state.json**; state.json is born at CP1.
- Drift audit variant: draft the delta against the existing docs instead
  of from scratch; everything else (interview, checkpoint, seal) is the
  same path.

### 1. Scan & draft (automated, provenance-marked)

Run three read passes over the repo (spawn Explore agents where useful —
they locate, you judge):

- **Arch Hat:** entry points, module boundaries, data flow, persistence,
  integrations → ARCHITECTURE draft (+ `docs/architecture/` for detail).
- **QA Hat:** test setup, error-handling patterns, validation, auth →
  test-conventions + security-baseline drafts.
- **component-scout:** run `node scripts/gen-component-registry.mjs`, then
  write the missing doc blocks into the components it reports as
  undocumented (purpose + "not for" are interview material, not
  extractable) and regenerate → components.md registry;
  design tokens (tailwind config, CSS custom properties) →
  DESIGN-SYSTEM draft. If no real tokens exist, write a pointer to the
  **frontend-design** skill (1c) instead of inventing a design system.

Draft ALL eight files into `specs/intake/` with a provenance marker on
EVERY statement:

- `[extracted: <file:line evidence>]` — derived from code/README/git
  history, with the evidence reference
- `[assumed]` — plausible inference that needs developer confirmation
- `[gap: <question>]` — cannot be derived from code; must be asked

While drafting, collect every detected **inconsistency** (e.g. "errors
via Result type in ~60% of modules, thrown exceptions in ~40%") into the
interview queue — never silently pick a winner.

Near-greenfield variant: almost no code → extraction is thin and sourced
from concept/PRDs; the interview carries the weight. Same files, same
markers, same path.

### 2. Developer interview (point by point)

Build ONE numbered queue: every `[gap]`, every `[assumed]`, every
detected inconsistency. Work through it point by point with
AskUserQuestion — grouped by topic, never as one wall of questions.

- Every answer becomes a GUIDELINES rule (or a PRODUCT/ARCHITECTURE
  statement, wherever it belongs).
- For inconsistencies: the developer picks the rule going forward; the
  LOSING pattern becomes a **Known Debt** note in GUIDELINES — recorded,
  not silently rewritten.
- `[assumed]` items the developer confirms lose their marker; corrected
  ones are rewritten from the answer.

### 3. Reconcile via checkpoint (4a, Bootstrap Variant)

Route to the **checkpoint** skill's Bootstrap Variant: the generated
docs are HYPOTHESES, not truth. Same point-by-point pattern — every
review point ends in exactly one of adopt / change / reject / defer,
recorded in `specs/intake/decisions.md` (`D-BOOTSTRAP-<NN>` ids,
`templates/decisions.md.tmpl` frame) BEFORE the next point. Cascade
every decision into the affected draft(s).

### 4. Seal

1. Move the reconciled drafts to their final locations (`docs/*`, root
   `AGENTS.md`) and STRIP all provenance markers — they are working
   syntax, the sealed baseline never carries them.
2. `bash scripts/intake-seal-check.sh` (copy from
   `~/.claude/skills/0b_intake/scripts/` together with
   `curation-caps.sh` if missing). It verifies: all eight files exist,
   zero residual markers, `specs/intake/decisions.md` carries
   `D-BOOTSTRAP` reconcile decisions (undiscussed drafts never seal),
   file caps hold. Red → fix, re-run; NEVER seal past a red check.
3. Commit: `docs: intake baseline — initial curated docs`
   (include `specs/intake/decisions.md`).

From here on, P7 curation owns every docs/ update.

→ NEXT ACTION: start the first PROJ through the chain (**chain-guide**
routes it); at P0 the setup skill compiles this baseline into the
context bundles.

## Failure Behavior

- The interview cannot proceed (developer unavailable) → leave the
  marked drafts in `specs/intake/`, write one line to `specs/intake/`
  README noting the open queue — the drafts are resumable; nothing is
  half-sealed into `docs/`.
- `intake-seal-check.sh` red → the baseline stays uncommitted; fix and
  re-run. The check is idempotent.
