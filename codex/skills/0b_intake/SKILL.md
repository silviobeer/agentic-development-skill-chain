---
name: intake
description: "Bootstrap the curated context baseline for a brownfield (or near-greenfield) repo: scan the code and draft ALL curated docs with per-statement provenance markers, interview the developer through every gap/assumption/inconsistency, reconcile via the checkpoint loop, then seal as the initial curation baseline commit. Use when: (1) a repo has code but no curated docs/ baseline (docs/PRODUCT.md missing), (2) an explicit drift audit of the curated docs is requested, (3) a near-greenfield project needs its baseline before the first PROJ. Not for: per-PROJ documentation (use documentation), ongoing doc updates (P7 curation owns those), plan approval (use executing-large-model, which runs Checkpoint 1)."
---

# Intake — Bootstrap the Curated Context Baseline

## Session Boundary

Through Step 4, each producing skill runs in its own user-started session.
Complete this skill's checks, automatic cross-review, reconciliation and required
user review here, then stop at the handoff. Do not invoke the next producing
skill, including a prerequisite or another PROJ, in this session. Internal
helpers and cross-review remain in this session. `/compact` is not a new session.
End with a copyable start prompt naming the next skill, workspace, PROJ (if any),
actual input artifact paths and any blockers. The next session reads those
artifacts rather than relying on chat history. Do not create a separate session-context file.
If blocked, name the owning skill and issue in the prompt; do not claim readiness.
If the track is complete, report completion without inventing a next step.
Show progress: run `bash ~/.claude/skills/5_executing/scripts/chain status --short <X>` (Codex: `~/.codex/skills/5_executing/scripts/chain`; `<X>` is this PROJ's number, or `new` while none is allocated yet) when this session starts and again just before the handoff prompt, and show its line unchanged; if it prints nothing or fails, continue without it.


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

## Codex Adaptation

This skill is aligned with the Claude variant. In Codex:

- Reusable skill assets live under `~/.codex/skills/...` instead of
  `~/.claude/skills/...`.
- No AskUserQuestion tool and no Explore subagents: run the prepare step
  (the three scan passes and the drafting) and the apply step inline, and
  run the interview as numbered question blocks in the conversation (one topic per block, wait for the
  answers before the next block).
- Everything else — provenance markers, the interview queue, the
  checkpoint reconcile, the seal check — is identical.

## Output (the baseline — all nine files)

| File | Content | Cap |
|---|---|---|
| `docs/PRODUCT.md` | what the product is, for whom, non-goals | ½ page (≤30 non-blank lines) |
| `docs/ARCHITECTURE.md` | the load-bearing architecture truths as current state, in the sections `Stack` · `System shape` · `Data ownership` · `Invariants` (`0c_bootstrap` § 3); details → `docs/architecture/` | ≤200 lines |
| `docs/GUIDELINES.md` | target-state rules by topic + `## Traps` (≤10 top-level list entries, each `Don’t X → instead Y — why it happens here`; use the [trap test](../../../CONCEPT.md#trap-test-and-rule-placement)) | ≤120 lines |
| `docs/review-checklist.md` | `## Antipatterns`: project-specific checks with detection signal and severity; `## Known Debt`: do not re-flag, do not spread | ≤80 lines |
| `docs/DESIGN-SYSTEM.md` | design **rules** extracted from code — tokens, scales, patterns, do/don't — or a pointer to **frontend-design** (1c) if none exist; never invented. No component inventory (that's `components.md`) | ≤80 lines |
| `docs/components.md` | component registry — **generated** by `scripts/chain render registry` from the doc block above each component export | — |
| `docs/security-baseline.md` | auth model, secret handling, input validation floor | ≤60 lines |
| `docs/test-conventions.md` | test runner, layout, naming, what must be tested | ≤60 lines |
| `AGENTS.md` (root) | initial durable agent rules | ≤40 non-blank lines |

`docs/review-checklist.md` is required to seal; a thin file with both headers beats an absent one. Generic role rules stay in the chain manifests, never duplicated in project Traps.

`docs/DESIGN-SYSTEM.md` and `docs/components.md` are only required to seal
when the repo has a component directory (`src/components` or
`src/features/*/components`); backend-only repos skip both (see
`scripts/chain check intake`).

**Existing AGENTS.md (or other curated docs) are baseline truth, never
overwritten.** If a file already exists, the draft is a MERGE: every
existing rule/statement is kept unless an interview decision explicitly
retires it (recorded in `decisions.md`); new content is appended with
provenance markers like everything else. The drift-audit variant works
the same way — deltas, not rewrites.

## External workspace context (optional)

When routed by `handoff-refinement`, use its [workspace contract](../2e_handoff-refinement/references/workspace-contract.md). This lifecycle is per code repository, independent of incoming features. Reuse a complete team-accepted baseline at its recorded commit; check visible intake branches/PRs and coordinate with their owner before starting another. Resume incomplete/interrupted intake even when `docs/PRODUCT.md` already exists, preserving the interview, merge and seal rules below. Missing documents alone do not authorize overwriting existing ones. A new handoff never triggers a fresh intake or drift audit; suspected drift requires an explicit audit request.

Read external product requirements as proposed future context only. Never document unimplemented requirements as current code truth. The repo's `docs/PRODUCT.md` states its responsibility and may reference shared product context without rewriting product-owned feature requirements. Coordination-only repositories are exempt from application intake. Planned code repositories use bootstrap with approved scope.

At handoff, report the local seal commit/check evidence separately from any accepted team revision and its review evidence. An unmerged PR or local seal is not team acceptance. Return those facts to workspace onboarding with a copyable next-session prompt; do not update feature state or auto-run intake in another repo. These team rules add no PR gate to standalone linear intake.

## Workflow

### 0. Precondition

- No curated baseline yet (`docs/PRODUCT.md` missing), an existing incomplete/interrupted intake to resume, OR the user
  explicitly asked for a drift audit of the existing baseline.
- Working space: `specs/intake/` (drafts + decision log). This is
  pre-PROJ — there is **NO state.json**; concept (1) creates one per PROJ.
- Drift audit variant: draft the delta against the existing docs instead
  of from scratch; everything else (interview, checkpoint, seal) is the
  same path.

### 1. Prepare (subagent): scan, draft, build the queue

Spawn ONE prepare subagent (foreground; inline where subagents are
unavailable, as in the checkpoint **Roles**). It runs the scan and the
drafting below and returns only the numbered interview queue (≤ 300
tokens plus artifact paths) — scan output and drafts never sit in the
interview session.

Run three read passes over the repo (spawn Explore agents where useful —
they locate, the prepare subagent judges):

- **Arch Hat:** entry points, module boundaries, data flow, persistence,
  integrations → ARCHITECTURE draft (+ `docs/architecture/` for detail).
- **QA Hat:** test setup, error-handling patterns, validation, auth →
  test-conventions + security-baseline drafts.
- **component-scout:** run `bash scripts/chain render registry` (it
  scans every outermost `components/` folder under `src/`; nested app root:
  `bash scripts/chain render registry <app> --out docs/components.md`), then
  write the missing doc blocks into the components it reports as
  undocumented (purpose + "not for" are interview material, not
  extractable) and regenerate → components.md registry;
  design tokens (tailwind config, CSS custom properties) →
  DESIGN-SYSTEM draft. If no real tokens exist, write a pointer to the
  **frontend-design** skill (1c) instead of inventing a design system.

Draft the nine baseline files into `specs/intake/` as applicable: the seven
core files, including `review-checklist.md`, are always required; the two UI
files follow the component-directory condition in the output table above.
Put a provenance marker on EVERY statement:

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

### 2. Interview and reconcile (one pass)

The orchestrator (this session) walks the queue ONCE as numbered question
blocks — grouped by topic, never as one wall of questions. This is the
checkpoint loop (`references/bootstrap-reconcile.md`): every queue item
(`[gap]`, `[assumed]`, detected inconsistency) ends in exactly one of
adopt / change / reject / defer, recorded in `specs/intake/decisions.md`
(`D-BOOTSTRAP-<NN>` ids, `templates/decisions.md.tmpl` frame) BEFORE the
next item. The apply subagent cascades each decision into the drafts;
the orchestrator edits no draft.

- Every answer becomes a GUIDELINES rule (or a PRODUCT/ARCHITECTURE
  statement, wherever it belongs).
- For inconsistencies: the developer picks the rule going forward; the
  LOSING pattern becomes a **Known Debt** note in the `review-checklist` draft
  in `specs/intake/`; the seal step promotes it to `docs/review-checklist.md` —
  recorded, not silently rewritten.
- `[assumed]` items the developer confirms lose their marker; corrected
  ones are rewritten from the answer.

### 3. Seal

1. Move the reconciled drafts to their final locations (`docs/*`, root
   `AGENTS.md`) and STRIP all provenance markers — they are working
   syntax, the sealed baseline never carries them.
2. `bash scripts/chain check intake` (no `scripts/chain` yet: use
   `~/.codex/skills/5_executing/scripts/chain`, which finds the helpers in the
   installed skills). It verifies the nine baseline files subject to the
   output table’s UI condition: seven core files always exist (including
   `review-checklist.md`), plus both UI files when component directories exist;
   zero residual markers; `specs/intake/decisions.md` carries
   `D-BOOTSTRAP` reconcile decisions (undiscussed drafts never seal),
   file caps hold. Red → fix, re-run; NEVER seal past a red check.
3. Commit: `docs: intake baseline — initial curated docs`
   (include `specs/intake/decisions.md`).

From here on, P7 curation owns every docs/ update.

→ NEXT ACTION: start the first PROJ through the chain (**chain-guide**
routes it); at P0 the setup subskill compiles this baseline into the
context bundles.

## Failure Behavior

- The interview cannot proceed (developer unavailable) → leave the
  marked drafts in `specs/intake/`, write one line to `specs/intake/`
  README noting the open queue — the drafts are resumable; nothing is
  half-sealed into `docs/`.
- `chain check intake` red → the baseline stays uncommitted; fix and
  re-run. The check is idempotent.
