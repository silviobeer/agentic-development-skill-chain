# Agent Workflow Framework — Concept

**Status:** Draft v0.23 — under iteration (leading version; the German
KONZEPT.md is frozen at v0.9)
*(v0.4: context-economy review — session-per-phase, spawn tiering,
scripts instead of LLM for deterministic work, budget enforcement)*
*(v0.5: git/subagent review — tiering via agent types, manually managed
story worktrees, gotcha channel for parallel waves, Claude Code mapping §6b)*
*(v0.6: ponytail adopted as a ready-made plugin — retired 2026-10-26, see §7; manifest schema
following the claude-skills taxonomy in Stage 2; consolidated CLI list §7)*
*(v0.7: executive summary + overall diagram)*
*(v0.8: checkpoint skill `4a_checkpoint` — structured reconcile loop
for CP1, bootstrap validation, and CP2/PR comments)*
*(v0.9: PRD source Jira + Teklens — import adapter `2d_prd-import`,
local PRD snapshot, Jira sync-back, commit IDs carrying Jira keys)*
*(v0.10: two PRD intake modes — local repo PRDs (default for now) and
Jira import (TODO); the new chain is tested without Jira first)*
*(v0.11: upstream responsibility — developers enrich PM PRDs with
technical stories, re-cut them, and own the story-set selection for the
agentic loop)*
*(v0.12: Appendix A — Docker ideas supporting the workflow; explicitly
out of scope, developer-owned)*
*(v0.13: sequential execution is the DEFAULT; three execution modes —
shared-checkout teams as the cheap middle tier, worktrees opt-in and
evidence-gated; "scripts ship with skills" convention + inventory §7)*
*(v0.14: deterministic output layer — "LLM decides, scripts render":
script specifications with input/output/exit contracts, template
inventory, JSON schemas validated on write)*
*(v0.15: `0b_intake` fully specified as a collaborative skill —
extraction with provenance markers + developer interview for gaps,
assumptions, and code inconsistencies; near-greenfield variant)*
*(v0.16: cross-model review — skill `cross-review`: Codex CLI as an
adversarial SECOND model for the P3/P4 pre-mortems and the P7
curated-docs review; pattern borrowed from grill-me-codex, not adopted
as a plugin; findings → ledger, blocking per §8)*
*(v0.17: symmetric Claude + Codex execution — host-neutral phase runner,
parallel model lanes with single-writer safety, provider-opposite review,
current pre-PRD discovery flow preserved, root AGENTS.md corrected,
Stage 1 made dependency-complete)*
*(v0.18: P6 ownership settled — Skill 6 remains a read-only finder;
the P6 phase controller owns ledger triage, fix dispatch, and fresh
provider-opposite re-verification)*
*(v0.19: review reconcile — dual-provider is PREFERRED, not hard:
degraded single-provider mode with model-opposite review fallback;
cost reconciled via model tiering per role; Mode 2 restored as the
cheap shared-checkout middle tier inside the writer lane; gotcha
channel and gate enforcement given provider-neutral mechanisms;
P3 authorship and state.sh sequencing specified)*
*(v0.20: product level above the PROJ — `0a_product-vision`
(docs/PRODUCT.md + numbered PROJ map in specs/product-roadmap.md) and
`0c_bootstrap` (stack into docs/ARCHITECTURE.md § Stack as the single
source of truth, real scaffold verified green, root AGENTS.md +
CLAUDE.md pointer); the design-system showcase gets a fixed structure
and a drift gate)*
*(v0.21: focused `bugfixing` workflow outside the feature chain;
opposite-provider review expanded to required Requirements and six-persona
QA gates plus automatic concept/architecture/plan reviews; Codex → Claude
hardened with auth preflight, isolated validated structured output, a
conservative default input cap with explicit diff omissions, and handling of Claude's 10 MB stdin
ceiling)*
*(v0.22: `4a_checkpoint` and `4b_setup` folded into `5_executing` as
subskills (`subskills/checkpoint.md`, `subskills/setup.md`) run in
subagents; the orchestrator keeps the CP user dialogue; execution helpers
deduplicated into `5_executing/scripts/`; document validators live with their
producing skills (2–4), sharing pure readers with the execution context compiler; § references below use the new
names, the roadmap and version notes keep the historical ones;
`5b_executing-large-model` becomes the default Step 5 and runner P5 skill,
`5_executing` the full-procedure alternative for weaker writer models)*

*(v0.23: role-based rule placement — trap test, nine baseline files, reviewer-only
checklist and post-writing self-review access; capped project Traps)*

**Date:** 2026-10-26
**Basis:** the repository's aligned Codex + Claude SkillChain 0–8
(`codex/skills/`, `claude/skills/`) at the current main branch

Document gates: Step 2 checks PRD structure before user/provider review; Step 3
checks PRD inputs and architecture output; Step 4 checks both inputs and its
plan/config output. CP1 repeats all three before approval. Review owns meaning
and completeness. Context compilation remains with execution and preserves
legacy behavior for approved P5 runs; new explicit gates require older artifacts
to be corrected by their owning skill.

**Settled decisions (v0.2):**
- The framework is optimized against our own product; distributability
  maybe later → no early packaging/skill CI, stay lean.
- After Checkpoint 1, as autonomous as possible; overnight runs are the
  normal case → autonomy policy in §8; no "ask the user" between the
  checkpoints.
- Infrastructure is rudimentary at first (CI optional), the codebase will
  potentially become large → do the intake bootstrap NOW while it is
  cheap; context budgets and curation are designed for growth.
- 5b (`5b_executing-large-model`) stays lean: shared rules live once in
  `5_executing/references/`, both skills point to them, 5b is updated
  rather than regenerated from 5, and `validate.sh` caps it (350 lines)
  and rejects orphaned references.

---

## Executive Summary

**What:** An agent workflow framework built on the existing
SkillChain 0–8 that turns PRDs into production-ready, reviewed,
documented pull requests fully automatically — including overnight.
PRDs arrive via one of two intake modes: written directly into the repo
(the existing structure — the DEFAULT for the first runs) or imported
from Jira, where Teklens creates/enriches them (TODO, Stage 3; adds
status/PR-link sync-back). Downstream, both modes are identical. The human
intervenes at exactly two points: approving architecture + plan, and
merging the PR. Both checkpoints run as a structured reconcile loop
(checkpoint subskill of `5_executing`): feedback is collected point by point, recorded in a
decision log, and written back into all affected artifacts in a cascade.
Everything in between runs autonomously; on defined stop conditions the
run is parked in a controlled way (rescue branch, stop report), and every
run ends with a one-line summary + push notification (morning report
rendered on demand, see §8).

**How:** A host-neutral runner starts fresh Claude and Codex lanes per
phase and runs them concurrently wherever their work is independent
(handoff only via `state.json` and structured lane outputs — no compact
roulette). Concurrency of MODELS is the default; concurrency of WRITES is
not. One lane owns each artifact/file at a time, while the other produces
an independent proposal, test strategy, or review. User stories run in
dependency waves; every wave is checked by a hard gate
(ACs/tests, build, CodeRabbit review, browser smoke). Sonar's `sonar_cmd`
runs once per PROJ, at the PROJ-end Quality Gate, not per wave (§7).
Mode 1 pairs both providers concurrently around one write owner;
file-disjoint stories may run as a shared-checkout team inside the
writer lane (Mode 2, cheap); isolated writer processes with worktrees
and a merge gate (Mode 3) are opt-in, enabled only if telemetry proves
the nightly window overflows. All review sources flow
into stage-local findings ledgers aggregated per PROJ with a single fix queue;
Medium/Low findings are automatically deferred as marked debt instead
of prompting the user. Requirements, QA evidence, pre-mortems, and curated
docs additionally pass provider-opposite adversarial review via
`cross-review`: Claude
reviews Codex-authored artifacts and Codex reviews Claude-authored
artifacts. Joint artifacts receive independent reviews from both lanes
before reconciliation, so an authoring model never grades its own work
alone. If the degradable Codex lane is unavailable, the run continues with
Claude and a model-opposite reviewer: the strongest Claude model that is not
the author model (rank `fable opus sonnet`, so Opus reviews Fable-authored
artifacts and Fable reviews Opus-authored ones); the degradation is flagged in
the morning report and PR body. Claude remains the hard host dependency, and Codex-authored gates
that require Claude fail closed when Claude review is unavailable.

**Why it stays cheap:** Context is the most expensive resource. Hence:
curated half-page docs instead of full texts, injection only by spawn
class (micro-fixes get nothing), deterministic work runs as scripts
rather than through the LLM, and token budgets are enforced in the
preflight. Minimalism at code-writing time comes from the six
`## Minimal by default` rules in the implementer role manifests (§7). Dual lanes do NOT mean double flagship cost: every
lane runs the cheapest model adequate for its role (model tiering in
the role record — flagship models only for the few judgment-heavy
roles), so the second lane buys provider diversity at a fraction of
the writer's cost.

**Brownfield-first:** After the first run the product is brownfield
forever. A one-time intake bootstraps the curated docs (PRODUCT,
ARCHITECTURE, GUIDELINES) — from then on the curation step at the end of
every PROJ keeps them current and small.

```
               HUMAN ◇ CP1                                    HUMAN ◇ CP2
           approve arch + plan                            PR review + merge
           (5_executing checkpoint:                      (reconcile loop for
            reconcile + decision log)                     comments, via gh)
                  │                                                ▲
                  │                                                │
 PRDs: repo       │                                                │
 (A)/Jira (TODO)  │                                                │
  ─► P2d ─► P3 ─► P4                                               │
     import, arch.│  ┌─────────┐  ┌───────────────┐  ┌────┐  ┌────┐  ┌────┐
     (baseline +  └─►│ P0      │─►│ P5 EXECUTION  │─►│ P6 │─►│ P7 │─►│ P8 │
      delta),        │ SETUP   │  │ per wave:     │  │ QA │  │DOCS│  │ PR │
     wave plans      │ branch  │  │  implementers │  └─┬──┘  └─┬──┘  └─┬──┘
                     │ context │  │  → Ralph loop │    │       │       │
                     │ files   │  │  → wave gate  │  ledger  docs +  conflict
                     │ ground  │  │ paired lanes  │  dedupe  curation probe,
                     │ preflt. │  │ one writer;   │  → fix   (docs/,  PR body,
                     └─────────┘  │ multi opt-in  │  → debt  agent.md) CI checks
                                  └───────────────┘
   ─────────────────────────────────────────────────────────────────────────
   Cross-cutting: state.json (fresh Claude + Codex lanes per phase) · findings.json
                  morning report + push at run end · stop = rescue + report
   Context:       docs/ (curated, injected) · specs/PROJ-X-theme/ (short-lived)
                  src/**/agent.md (local, read explicitly)
```

**Where we stand:** All concept questions are decided (§11). Next step:
Stage 1 of the roadmap (§10) — phase runner, `8_delivery`, findings
ledger, autonomy policy. Then the bootstrap (Stage 2) while the codebase
is still small.

---

## 1. Goal and Principles

A framework that turns PRDs into production-ready, reviewed, documented
pull requests fully automatically — with exactly two human checkpoints.

### Principles

1. **Brownfield-first.** We are building on a product. After the first
   run it is brownfield forever. Every phase reads curated baseline docs
   and writes curated baseline docs back. Greenfield is the special case
   (first run), not the rule.
2. **Curation is a first-class process step.** Long-lived documents
   (architecture, product, guidelines, agent.md) go stale without active
   maintenance and then become a trap. Every PROJ ends with a curation
   step.
3. **Prevention over detection.** Minimalism rules and context belong in
   each worker's compiled context file, not only in reviews at the
   end. Code that is never written needs no review.
4. **Context economy: as much as necessary, as little as possible.**
   Four mechanisms: (a) one phase = fresh Claude and Codex lanes, handoff
   only via `state.json` + file paths; (b) context is tiered by spawn class —
   micro-fix spawns get NO file; (c) everything deterministic (dedup,
   rendering, state updates) runs as a script, never through the LLM;
   (d) budgets are enforced (token counting in the preflight), not just
   declared.
5. **One findings ledger.** All review sources (CodeRabbit, Sonar, code
   review, QA panel) flow into one deduplicated fix queue. Deferred
   findings become debt with an upgrade path, not forgotten.
6. **Machine-readable state.** `state.json` is the state machine
   (stage, wave, US status, SHAs). `progress.md` remains the
   human-readable view. Resume after crash/compact is deterministic.
7. **Exactly two checkpoints.** (1) Architecture + plan approval,
   (2) PR merge. Everything in between runs autonomously — including
   overnight. Between the checkpoints there are NO user questions; only
   defined stop conditions halt the run (§8 autonomy policy).
8. **Two models, one controlled write path.** Claude and Codex run as
   concurrent lanes, not as interchangeable host variants. Independent
   reasoning and review run in parallel by default. Writes are assigned
   to one lane per artifact/file or isolated in worktrees; two model
   processes never write the same checkout concurrently. Dual-provider
   is PREFERRED, not hard: if one provider is unavailable, the run
   degrades to single-provider with model-opposite review (§7) rather
   than stopping.

---

## 2. Process Overview

Once per product, before any PROJ: a new build runs `0a_product-vision`
(what the product is and is not, plus the numbered PROJ map that allocates
PROJ numbers and their order) and then `0c_bootstrap` (stack decided into
`docs/ARCHITECTURE.md` § Stack, real scaffold, agent files). An existing
codebase runs `0b_intake` instead — the same curated baseline, extracted
rather than decided. Exactly one of the two paths.

The repository's existing pre-PRD flow is preserved unchanged. A PROJ
starts with `1_concept` (optionally fed by a `1a_clarification`
stakeholder brief), optionally follows the UI branch
(`1b_visual-companion` → optional `1c_frontend-design` →
`1d_prototyping` → optional `1e_concept-sync`), and then runs
`2_requirements-engineer`. A small, bounded, non-bug change may instead take the
compressed entry `1f_fast-track-spec`, which writes the standard concept, one PRD and
the architecture in one session and hands off to `4_writing-plans`. On the product-discovery track it may continue
through `2b_handoff-package` and `2c_review-reconcile`, then stops; P3–P8
never run. Only a full-chain PROJ enters P2d/P3 below. Existing generated
`2b_handoff/` package runs remain immutable and are unrelated to the
`8_delivery` skill.

```
        ONCE PER PRODUCT (new build)     |  ONCE PER REPO (existing code)
        0a product-vision                |  0b intake
        0c bootstrap (stack + scaffold)  |  (same curated baseline)
              │
        EXISTING PRE-PRD FLOW (preserved)
        concept → UI exploration/mockups when needed → requirements
              │
              ├── discovery track → Linear / 2b_handoff package → STOP
              │
              └── full-chain track
              ▼
        PRDs: written directly into the repo (Mode A, DEFAULT)
              or originating in Jira via Teklens (Mode B, TODO)
              │
  ┌───────────▼───────────┐
  │ P2d PRD INTAKE        │  Mode A: files in specs/ are the snapshot
  │  (A: local, B: Jira)  │  Mode B: fetch epic+stories → normalize →
  └───────────┬───────────┘          check AC quality → sync-back later
  ┌───────────▼───────────┐
  │ P3  ARCHITECTURE      │  read baseline → draft delta → pre-mortem
  └───────────┬───────────┘
  ┌───────────▼───────────┐
  │ P4  PLANNING          │  waves, dependencies, contracts, gate config
  └───────────┬───────────┘
              ▼ ◇ CHECKPOINT 1 (human, via 5_executing checkpoint subskill):
                reconcile loop → decision log → cascade updates
                into artifacts → state.json "approved" unlocks P0
  ┌───────────────────────┐
  │ P0  SETUP             │  branch, worker context files, ground file, preflights
  └───────────┬───────────┘
  ┌───────────▼───────────┐
  │ P5  EXECUTION         │  per wave: implement → Ralph → wave gate
  │     (loop over waves) │  dual-model lanes; single-writer rules (§6)
  └───────────┬───────────┘
  ┌───────────▼───────────┐
  │ P6  QA                │  findings ledger: collect → dedupe → fix
  └───────────┬───────────┘
  ┌───────────▼───────────┐
  │ P7  DOCS & CURATION   │  docs + curation of all long-lived files
  └───────────┬───────────┘
  ┌───────────▼───────────┐
  │ P8  DELIVERY          │  conflict check, PR, CI polling
  └───────────┬───────────┘
              ▼ ◇ CHECKPOINT 2 (human): PR review + merge —
                comments via reconcile loop (fix now / debt /
                reject), principle feedback → GUIDELINES/AGENTS.md
```

Cross-cutting across P0 and P3–P8: concurrent Claude/Codex lanes,
`state.json`, `findings.json`,
telemetry (Ralph iterations, gate failures, fix spawns), statusline
(`PROJ-3 · Wave 2/5 · QA pending`).

---

## 3. Brownfield Model

### Greenfield Counterpart — Skill `0a_product-vision`

The baseline below is reached by extraction because code exists. On a NEW
product there is nothing to extract, so the same `docs/PRODUCT.md` slot is
reached by decision instead: `0a_product-vision` interviews the product
owner and cuts the product into the numbered PROJ map in
`specs/product-roadmap.md` — where PROJ numbers are allocated, where
`chain-guide` reads the order and `1_concept` takes its scope boundary. The
map is not injected, so it costs no token budget; `docs/PRODUCT.md` keeps its
cap. `0c_bootstrap` then decides the stack into `docs/ARCHITECTURE.md`
§ Stack — the single source of truth for technology, inherited by
`3_architecture`, which never re-opens the choice — runs the real scaffold
green and writes root `AGENTS.md` plus the `CLAUDE.md` pointer. Run exactly
one baseline path (`0a` + `0c` for a new build, `0b` for an existing
codebase); neither overwrites the other's output. Procedures:
[0a_product-vision/SKILL.md](claude/skills/0a_product-vision/SKILL.md),
[0c_bootstrap/SKILL.md](claude/skills/0c_bootstrap/SKILL.md).

### First Run (Bootstrap) — Skill `0b_intake`

The first run on an existing product starts with a one-time intake,
owned by a dedicated skill. Its core principle: **extraction and
interview are two different sources, and the skill needs both.** Code
can tell you what IS; only the developer can tell you what is
INTENDED — product scope and non-goals, security requirements, and
which of two inconsistent code conventions is the rule going forward.
The intake is therefore a collaborative session with the developer,
not a batch job.

**Provenance markers** make the two sources visible: the scan drafts all
nine baseline files with a marker on every statement — `extracted` (with
file evidence), `assumed` (needs confirmation), `gap` (must be asked) — and
every detected inconsistency goes into the interview queue, never silently
decided. The developer interview works the `gap`/`assumed` items and
inconsistencies point by point through the checkpoint loop (§4; the
losing pattern becomes a known-debt note, not a rewrite); the sealed
baseline carries no markers, passes the file caps (§5) and is committed as
the initial curation baseline. From then on P7 curation owns every update;
`0b_intake` is re-run only as a deliberate drift audit. Steps, the nine
files and the near-greenfield variant (thin extraction, the interview
carries the weight): [0b_intake/SKILL.md](claude/skills/0b_intake/SKILL.md).

**Timing:** AS EARLY AS POSSIBLE — while the codebase is small the intake
is cheap; from then on the curated docs grow with every PROJ (P7 curation)
instead of being reverse-engineered against a large codebase later.

### Every Subsequent Run

Reads the curated baseline (P3 step 1), builds against it, and at the
end (P7) writes the surviving decisions back. The baseline is the single
source for "how this product is built" — PRDs describe only what is new.

---

## 4. Phases in Detail

### P2d — PRD Intake (two modes)

**Upstream responsibility — PRD readiness (applies to BOTH modes):**
PM-generated PRDs (created outside this process) are NOT directly
executable input for the agentic loop. Before intake:

1. **Developers enrich them with technical stories** — migrations,
   refactors, infrastructure work, test scaffolding: the things a PM
   does not write but the build requires.
2. **Developers re-cut and re-order the stories into PRDs** (in Jira
   for Mode B) so that each PRD is a coherent, buildable unit.
3. **It is the DEVELOPER's responsibility to send the right set of user
   stories into the agentic loop.** The framework validates AC quality
   (deterministic testability) but NOT scope selection — what goes in is
   a human engineering decision, not the pipeline's. A wrong or
   incomplete story set produces a technically clean PR for the wrong
   scope; no gate downstream catches that.

**Both intake paths are supported; everything downstream of the snapshot
is identical**, because both modes produce the same artifact: PRDs in
the chain format at `specs/PROJ-<X>-<theme>/2_PRDs/*.md` (user stories with
Given/When/Then + ACs). P3 onward never knows or cares where a PRD came
from.

**Mode A — local repo PRDs (DEFAULT for now):** PRDs are written
directly into the repo, as today — via Skill 2
(`2_requirements-engineer`) or by hand. No import step, no sync-back;
the files in `specs/PROJ-<X>-<theme>/2_PRDs/` simply ARE the snapshot. **The new
chain is tested in this mode first.**

**Mode B — Jira import (TODO, not needed for the first runs):** PRDs
originate in **Jira** — created or enriched by **Teklens** (teklens.ai:
AI planning platform that builds a knowledge graph from code, Jira, and
Confluence and translates specs into Jira tickets with code context).
The import skill `2d_prd-import` (build in Stage 3):

1. **Fetch:** pull the epic + its stories from Jira
   (mechanism: Atlassian MCP or Jira CLI/REST — decided at build time,
   Stage 3).
2. **Normalize the snapshot:** convert into the chain PRD format
   (`specs/PROJ-<X>-<theme>/2_PRDs/*.md`, user stories with Given/When/Then +
   ACs). **The local snapshot is the working truth for the entire run**
   — gates and Ralph need stable AC texts; Jira is not re-read mid-run
   (context economy + determinism). If the ticket changes during the
   run, the snapshot governs; the delta becomes visible at the next
   import.
3. **ID mapping:** Jira keys are passed through — commit format
   `feat(JIRA-123): …` or `feat(PROJ-X/JIRA-123): …`, and the PR body
   links the keys. This keeps Jira automation AND the Teklens graph
   (which reads git history) in sync automatically.
4. **AC quality check:** Teklens delivers code-grounded specs, but the
   chain needs DETERMINISTICALLY verifiable ACs (Ralph loop = test
   commands). The import checks every story: are the ACs phrased
   testably? Missing/vague ACs → findings list that is either decided at
   the CP1 reconcile (via the checkpoint subskill) or played back as a Jira
   comment.

**Sync-back (Mode B only, during/after the run):**
- Status transitions per story (In Progress → Done) on US completion
- PR link + short result (gate/QA status) on the epic/stories
- Deferred debt with Jira reference as a comment on the ticket
- The morning report links the Jira keys

In Mode A there is no sync-back target; commit format falls back to the
existing `feat(PROJ-X-PRD-Y): …` scheme. The AC quality check (step 4)
is worth running in Mode A too — as part of the plan self-review in P4.

**Synergy instead of duplicate work:** Teklens builds its own context
graph from code + Jira + git — our job is only to keep its inputs clean
(Jira keys in commits/PRs, status sync). `docs/` nevertheless remains
our own agent context layer: Teklens serves product planning, `docs/`
serves the implementing agents.

### P3 — Architecture (input: PRDs only)

1. **Read the baseline:** `docs/ARCHITECTURE.md`. If it is missing →
   intake (see Brownfield Model). Verify stale-looking sections against
   the code.
2. **Draft the delta:** `specs/PROJ-<X>-<theme>/3-4_plan/PROJ-<X>-architecture.md` —
   only the NEW decisions of this PROJ, each with `Affects` and a one-line
   `Summary`. References standing decisions instead of repeating them
   ("uses the standing auth decision; NEW: event queue for status
   transitions, because …"). A decision that changes the baseline says so
   with `Changes baseline: docs/ARCHITECTURE.md § <section>`. It is the ONE
   architecture file: the implementer view is compiled from it (§5), never
   written as a second file.
3. **Pre-mortem:** automated review (the-fool modes: devil's advocate,
   pre-mortem, evidence audit) against architecture + PRDs, PLUS a cross-model
   pass via `cross-review` (below). Authorship is explicit:
   `state.json` assigns ONE provider as the delta author
   (framework.config; alternates per PROJ by default). The non-author
   lane starts from the same bounded input in parallel and produces an
   independent risk-and-assumption sketch — that sketch feeds the
   pre-mortem as input, it is not a second delta to reconcile. The
   non-author then delivers the blocking critique.
4. **Derive contracts:** interfaces between soon-to-be-parallel stories are
   pinned down before execution, not guessed by implementers. The architecture
   names the boundary; `writing-plans` (P4) writes
   `specs/PROJ-<X>-<theme>/api-contracts.md` with one `## Wave N: <interface>`
   section per wave once it knows which stories run in parallel — the bundle
   compiler injects only the running wave's sections.

### Cross-Model Review Skill `cross-review` (new)

Same-model review is an echo chamber: the model that made the
decisions, wrote the code, and curated the docs will grade its own
summaries as accurate. The-fool personas vary the PROMPT, but not the
provider — blind spots survive persona rotation. This skill is
symmetric: Claude-authored artifacts go to Codex (`codex exec`) and
Codex-authored artifacts go to authenticated Claude (`claude -p`). Both
invocations are headless, strictly read-only, and bounded. Claude uses a
validated JSON Schema and the adapters normalize both providers into the
same JSON-lines contract. `state.json` records the authoring lane for every
reviewed artifact; a review from the same provider does not satisfy the gate.

**Pattern sources:** grill-me-codex
(github.com/chaseai-yt/grill-me-codex) for the adversarial-review thesis;
OpenAI's `codex-plugin-cc`
(github.com/openai/codex-plugin-cc) for Claude → Codex delegation; and
the Codex-facing `claude` skill
(github.com/tomzhengy/harness-configs/tree/main/codex/skills/claude)
plus ConsultClaude (github.com/Retro2512/ConsultClaude) for Codex →
Claude. The latter prove the reverse `claude -p` path exists today.
The framework keeps its own thin adapters because it needs one stable
JSON-lines contract, ledger integration, budgets, and identical failure
semantics in both directions; it does not make either third-party plugin
a core dependency.

**Producing-skill call sites (analogous to the checkpoint subskill):**

| Call site | Artifacts reviewed | Review focus |
|---|---|---|
| Concept review (automatic) | written concept | missing assumptions, contradictions, scope and feasibility risks |
| Requirements review (required) | complete PRD set + approved concept + compact UI contracts | gaps in stories/ACs/edge cases, contradictions, untestable requirements |
| P3 pre-mortem (automatic) | PROJ architecture + migration design when present, against PRDs | wrong/missing decisions, unstated assumptions, contradictions with the baseline |
| P4 plan review (automatic) | wave plans + wave-gate-config + api-contracts | unsafe ordering, weak AC commands, missing contracts |
| P6 QA review (required) | QA summary/evidence + implementation diff | evidence integrity, release decision, security, architecture, performance, reliability, cross-wave drift, minimalism |
| P7 docs review (required) | curated docs delta (+ full capped docs) vs. the PROJ diff | factual accuracy ("does ARCHITECTURE.md describe what was actually BUILT?"), stale claims, cap-gaming (shrinking docs by deleting true load-bearing statements) |

All six call sites are blocking gates. Concept, architecture, and plan review
start automatically in the producing turn as soon as their complete outputs
are saved (and plan validation passes), before user approval or handoff.
No opt-in prompt is required. P6 runs six isolated discipline reviewers rather
than asking one process to simulate a panel. The P7 call site is especially
critical: curated docs are injected into
every future implementer — a wrong statement there poisons every
subsequent PROJ. Hence BLOCKING, not advisory.

**Mechanics and degraded mode:** `chain review` routes to the provider
opposite the recorded author, normalizes both providers into one findings
JSON-lines contract for the ledger, and re-reviews automatically for up to
three rounds (manual rounds unlimited); Critical/High block the phase, the
rest is reported or deferred as debt per §8. Provider-opposite is PREFERRED,
not hard: without Codex, Claude-authored work falls back to the strongest
Claude model that is not the author's (rank `fable opus sonnet`), flagged
in the morning report and PR body — the invariant that survives degradation
is that the gate is never satisfied by the authoring model, except the
six-persona QA fallback, which runs on the strongest Claude model even when it
is the author's and is flagged degraded. Routing, that fallback and the output-integrity rules are in
[cross-review/SKILL.md](claude/skills/cross-review/SKILL.md#routing-and-output-integrity);
the pinned writer/review models in
[runner/README.md](runner/README.md#invariants-the-runner-owns).

### Focused Bug Repair Skill `bugfixing` (optional)

Reported defects do not need a feature PROJ, new PRDs, architecture, or wave
plans unless diagnosis reveals feature-sized scope. `bugfixing` owns one defect
from normalized intake through safe baseline checks, deterministic or real-
browser reproduction, code-root-cause analysis, and explicit test-escape
analysis. Standalone evidence is written to
`specs/_bugfixing/BUGFIX-YYYYMMDD-HHMM-<slug>/bugfix-report.md`; when invoked inside a
framework PROJ, findings use the existing ledger and state machinery.

The repair contract is red-before-green: add or correct the smallest regression
test, prove it fails for the reported behavior before production code changes,
then dispatch a narrow `micro-fixer`. Re-run the original reproduction path and
the relevant suite after every repair. A Ralph loop is bounded to three repair
attempts; CodeRabbit is used only when available, and Sonar only when already
configured. Completion requires the original path green, regression proof, and
a recorded explanation of why the previous tests missed the defect.

### P4 — Planning (= Skill 4, extended)

- Wave plans + `wave-gate-config.json` as today.
- NEW: execution-mode decision per wave (§6): Mode 1 paired lanes
  (default) / Mode 2 shared-checkout team inside the writer lane — only
  with listed proof that the stories' file sets are disjoint / Mode 3
  worktree writers (only if activated, Stage 4). Two independent CLI
  processes never write the same checkout together in any mode.
- NEW: pre-mortem review of the wave plans (unsafe ordering, weak AC
  commands, missing contracts) — the-fool modes PLUS the cross-model
  pass via `cross-review`, which makes the old vague "have another
  model look it over" literal and structured.
- Then ◇ Checkpoint 1 — handled by executing's checkpoint subskill (below).

### Checkpoint Subskill (`5_executing/subskills/checkpoint.md`)

Checkpoints are not a "looks good? yes/no" question but a structured
reconcile loop (generalizing the proven `2c_review-reconcile` pattern):
present a compact review package instead of raw artifacts, walk it point
by point, close every point as `adopt` / `change (how)` / `reject (why)` /
`defer` in a durable decision log, cascade each change through ALL affected
artifacts (architecture, wave plans, gate config, api-contracts) and re-run
the plan validator, and only then seal — `CP1:approved` in `state.json` is
the only thing that unlocks P0. A round whose upstream cross-reviews were
already clean auto-adopts (fast path); anything a human had to judge gets
the full loop. The work runs in subagents (prepare → apply) while the
conversation stays with the calling orchestrator, because subagents cannot
reach the user. The same loop serves three call sites — CP1 (Step 5 lead),
the bootstrap checkpoint of `0b_intake` (§3) and CP2 in `8_delivery`
(PR comments classified `fix now` / `debt` / `reject with rationale`;
principle-level feedback becomes an AGENTS.md/GUIDELINES candidate).
Procedure and variants:
[checkpoint.md](claude/skills/5_executing/subskills/checkpoint.md).

### P0 — Setup (`5_executing/subskills/setup.md`; replaces the FIRST-ACTION block from Skill 5)

Once per PROJ, fully automatic, in one subagent spawned by the Step 5 lead
(or the runner's P0 lane); scripts run the checks, with bounded judgment for
assumptions and a safe negative control, no user questions. In order: gate on `CP1:approved` and the plan validator;
create or resume the persistent sibling worktree on `proj/PROJ-X`, tag
`BASE_SHA`, install dependencies there (source isolated; `.env.local`, the
development database and the hosted-auth budget shared and serialized
through the common lock); sync the framework helpers into the repo;
permission and CodeRabbit-config preflight; tool + auth preflight of the §7
list (both provider auth states, migration drift — `codex`
missing sets `degraded`, never silently); commit a checkpoint (the negative
control's clean-tree gate stays strict); verify the verifier with one
controlled red gate; suggest static-check commands; write the ground file
(validated assumptions `docs/` does not already state);
compile the worker files for every wave once — delivered by path in each
spawn prompt, no hook, canonical for both providers; seal `P0:done` with a
second setup commit. Procedure: [setup.md](claude/skills/5_executing/subskills/setup.md);
the sequence diagram and the worker-file layout in
[how-it-works.md](docs/how-it-works.md#p0-one-setup-run); lock diagnosis
and worker handover in
[worker-lifecycle.md](claude/skills/5_executing/references/worker-lifecycle.md);
the guarded post-merge worktree cleanup in
[8_delivery/SKILL.md](claude/skills/8_delivery/SKILL.md#5-seal-the-autonomous-part).

### P5 — Execution (= Skill 5, loop per wave)

```
for each wave N:
  1. Start Claude + Codex lanes (execution mode per wave plan, §6)
     – Mode 1 paired: one writer on the PROJ branch, the other lane
       prepares tests/risks and reviews; roles may swap by story
     – Mode 2 parallel, file-disjoint and runtime-safe → agent team in the
       writer lane's SHARED checkout; the lead owns declared shared resources,
       progress, staging, and commits; the peer lane stays read-only
     – Mode 3 parallel, overlap risk → own worktree + story branch each,
       then semantic merge gate
     – context is the worker's one compiled file (path in the spawn
       prompt); local knowledge via the agent.md reading protocol
  2. Per US: TDD by the worker, closed by ONE bounded Inner Ralph
     self-review (fix confirmed issues once, no AC verification)
     – learnings IMMEDIATELY into the folder agent.md (deepest
       applicable level)
  3. After all workers of the wave: ONE wave-scoped Outer Ralph pass
     (`chain gate wave --ac-only`, deterministic AC verification) with
     exactly four recovery stages — fix round 1, fix round 2 with fresh
     workers, fresh diagnosis without edits, a different implementer
     applies it; still red → blocked path, the AC is never weakened
  4. Mode 3 only: MERGE GATE — merge story branches into the PROJ
     branch in dependency order; auto-fix trivial conflicts; semantic
     conflicts = planning error → finding into the ledger + escalate
  5. WAVE GATE (`chain gate wave`, one script run): current ACs +
     declared regressions, optional static checks, smoke, build,
     CodeRabbit — never Sonar; findings → ledger, Critical/High block
  6. green → next wave without stopping
after the last wave (still P5):
  PROJ QUALITY GATE on the assembled diff BASE_SHA..HEAD — integration
  code review, build, optional `mutation_cmd`, coverage, Sonar once per
  PROJ, quality tests, lint → `chain quality seal` → P5 done
```

The wave gate certifies the current wave plus its declared regressions —
not every earlier AC — and structure is judged by tools that fail
(optional `complexity_cmd` / `arch_rules_cmd`), not by a cleaner agent. The
checks, their order, evidence reuse and the config keys are defined once in
the [Wave Completion Gate](claude/skills/5_executing/SKILL.md#wave-completion-gate)
and the [gate-config contract](claude/skills/4_writing-plans/references/wave-gate-config.md);
the four recovery stages in
[Wave-Scoped Outer Ralph](docs/executing-skill.md#wave-scoped-outer-ralph);
the quality gate in the [Quality Gate reference](claude/skills/5_executing/references/quality-gate.md).

### P6 — QA (= Skill 6, reorganized around the ledger)

**Ownership boundary:** Skill 6 remains a strictly read-only finder. It
tests, reviews, and writes findings; it never changes production code or
dispatches fixes. The P6 phase controller owns the state machine,
ledger processing, fix dispatch, and re-verification. This preserves an
independent QA verdict without sacrificing unattended repair.

The code review gate (`skillchain-reviewer`), build and the `sonar-scanner`
quality gate are NOT P6 streams: they form the PROJ Quality Gate that closes
P5 (above). P6 is QA only, and sequential: the read-only QA finder runs
first — browser E2E + red team + UI audit + persona panel (Skill 6) — and
its findings are ingested into the ledger before the controller starts.

Then the **P6 phase controller** processes the ledger while protecting
its own context:
- **Script (no LLM):** dedupe (file/line/category), normalize severity,
  prioritize, cluster the fix queue by file.
- **Spawned verifier batches:** weed out false positives
  (receiving-code-review discipline) — needs judgment but does NOT run
  inline; the controller receives only verdicts.
- **Fix spawns (tier 0)** per confirmed cluster. Fixers receive only the
  finding, code anchor, relevant `agent.md` excerpt, and verification
  command; they do not inherit Skill 6's QA identity.
- **Fresh provider-opposite re-verification:** after each fix batch, a
  new read-only QA lane from the provider opposite the fixer reruns only
  the affected checks. The fixer never certifies its own repair. Every
  fixer adds a regression test (red before, green after) in the project's
  existing test location; the controller reruns it first, and the opposite
  check covers only what a test cannot prove.

After three failed repair/re-verification attempts on the same
Critical/High finding, P6 enters the stop behavior in §8. Exit requires
no Critical/High open. Medium/Low → **auto-defer**
(no user prompt, unlike today's Skill 5/6): debt marker in the code
(`debt:` convention with ceiling + upgrade path) + ledger status
`deferred`. The human decides about debt at Checkpoint 2 based on the
debt section in the PR — not mid-run.

### P7 — Docs & Curation (= Skill 7, moved BEFORE the PR)

1. Generate/update documentation (README, PROJECT.md, TECHNICAL.md)
2. **Curation step (the brownfield core):** the long-lived docs are
   rewritten in place as current state — surviving decisions merged into
   `docs/ARCHITECTURE.md` driven by the `Changes baseline` lines (never a
   per-PROJ section; deviations recorded as "planned X, built Y,
   because …"), PRODUCT and GUIDELINES updated, AGENTS.md candidates
   through the approval pipeline, `docs/components.md` regenerated
   (`chain render registry`, never hand-edited), folder `agent.md` files
   curated. Procedure:
   [7_documentation/SKILL.md § 7](claude/skills/7_documentation/SKILL.md#7-curated-context-curation--p7-gates-framework-runs).
3. **Two gates:** FORM — `chain check caps` (all caps defined once in the
   header of [curation.sh](claude/skills/7_documentation/scripts/curation.sh))
   checks size; TRUTH — a `cross-review` of the docs delta against the PROJ
   diff (§4) checks factual accuracy, stale claims and cap-gaming. Critical/High
   findings BLOCK P7 (up to three automatic re-review rounds, manual rounds
   unlimited); Medium/Low → debt per §8.
4. Commit everything to the PROJ branch → docs are part of the PR

### P8 — Delivery (new)

1. Rebase/conflict probe against `main` (throwaway worktree,
   `git merge --no-commit --no-ff`)
2. Classify conflicts: trivial (lockfiles, imports, formatting)
   → auto-fix; semantic → risk assessment into the PR + escalate
3. Create the PR (gh CLI) — body rendered by a **template script** from
   state.json + ledger (no LLM rendering): what was built, gate/QA
   results, known gaps (e.g. declared external prerequisites), debt ledger, 📚 doc changes
4. CI polling (GitHub Actions, via `gh pr checks`); red checks with
   verbatim output to fix agents (max 3 attempts).
5. ◇ Checkpoint 2: human reviews and merges (asynchronously — for
   overnight runs, in the morning; see morning report §8)

---

## 5. Context Model

### Session Architecture: One Phase = Fresh Claude + Codex Lanes

The process does NOT run as one long session with /compact points
(lossy, unpredictable, dies on multi-PROJ queues) but as a **chain of
fresh lane pairs** — a thin runner starts Claude and Codex processes per
model-dependent phase (P3/P4, P5 possibly per wave, P6, P7; P0/P8 are
primarily deterministic scripts and start model lanes only for judgment):

- **Handoff exclusively via `state.json` + file paths.** No conversation
  history is carried over; everything important lives on disk
  (plans, progress, ledger, agent.md).
- Every lane loads only what its phase and role need: P6 knows no wave
  conversation history; P8 judgment lanes see only ledger, state, and
  diff. Both providers read the same compiled worker files.
- `/compact` is demoted from load-bearing element to emergency fallback
  within a Claude lane; Codex compaction/resume is equally non-load-bearing.
- Side effect: crash resume and a normal phase transition are the same
  mechanism (start session, read state.json, continue).

### Four Layers, Each with Its Own Lifecycle

| Layer | Location | Lifetime | Distribution | Updated |
|---|---|---|---|---|
| 1. Durable agent policy | project-root `AGENTS.md` | forever | host-native instruction loading | only via approved P7 candidate merge |
| 2. Curated repo docs | `docs/` | forever | compiled into the worker files | only via P7 curation |
| 3. PROJ artifacts | `specs/PROJ-<X>-<theme>/` | until merge | compiled into the worker files / path reference | during the PROJ |
| 4. Local knowledge | `src/**/agent.md` | forever | reading protocol (explicit) | immediately on learning; curated in P7 |

### Trap test and rule placement

> Would the model do it wrong without this sentence? If the wrong path is the
> model’s default, or the damage is expensive or invisible to QA, the Don’t belongs
> to the implementer, with the alternative and the reason. Otherwise it belongs to QA.

`docs/GUIDELINES.md` holds target-state rules grouped by topic and one `## Traps`
section (≤10 top-level Markdown list entries, each `Don’t X → instead Y — why it
happens here`; ≤120 lines for the whole file). Generic implementer Don’ts live only
in the chain role manifests; project-specific Traps live only in GUIDELINES.
Nothing appears in both. Use decision criteria rather than catalogs of artifacts.

`docs/review-checklist.md` (≤80 lines) holds `## Antipatterns` with project-specific
detection signals and severities, plus `## Known Debt`: do not re-flag, do not spread.
The generic antipattern catalog stays in QA §6.4. A thin checklist with both headers
is required to seal. At a cap, curate instead of appending or deleting load-bearing truth.

| Role | Rules and review context |
|---|---|
| Implementer (tier 1) | GUIDELINES including Traps; DESIGN-SYSTEM for frontend/full-stack; chain-owned generic rules in role manifest |
| Reviewer | PRODUCT, review criteria, diff scope + review-checklist by path; consult GUIDELINES and QA §6.4 for relevant rule/simplicity checks (DESIGN-SYSTEM by path for UI audit) |
| QA | GUIDELINES, relevant DESIGN-SYSTEM, review-checklist + QA §6.4 generic catalog and testing-antipatterns reference |
| Inner Ralph self-review | Only after writing, implementer reads review-checklist by path; never injected into an implementer bundle |

### Files

The nine baseline files are AGENTS.md plus PRODUCT, ARCHITECTURE, GUIDELINES,
review-checklist, DESIGN-SYSTEM, components, security-baseline and test-conventions
under docs/. DESIGN-SYSTEM and components are required only for repos with components.

```
AGENTS.md                      ← ROOT-ONLY durable agent rules

docs/                          ← LONG-LIVED, curated, injectable
├── PRODUCT.md                 ← "what am I even building" (capped)
├── ARCHITECTURE.md            ← § Stack (THE stack source of truth) +
│                                overarching architecture (capped)
├── architecture/…             ← details/ADRs, referenced only
├── GUIDELINES.md              ← target-state rules + ≤10 project-specific Traps (≤120 lines)
├── review-checklist.md        ← project antipatterns + Known Debt (≤80 lines; reviewer/QA)
├── security-baseline.md       ← security floor (≤60 lines)
├── test-conventions.md        ← test operations and conventions (≤60 lines)
├── DESIGN-SYSTEM.md           ← tokens, scales, patterns, do/don't (capped)
└── components.md              ← component registry (GENERATED from the code)

specs/product-roadmap.md       ← PROJ map: outcome, Depends on, Status
                                 (NOT injected — costs no context budget)

specs/PROJ-<X>-<theme>/        ← PROJ artifacts
├── 0_context/                 ← existing-state inputs when applicable
├── 1_concept/              ← approved concept + direction log (not injected)
├── 1b_visual-companion/        ← UI structure exploration when applicable
├── 2_PRDs/                    ← requirements snapshot
├── 1c_design/                  ← optional design language
├── 1d_prototypes/                 ← mockups + implementation handoff when applicable
├── 3-4_plan/                    ← architecture + wave plans + gate config
├── 5_progress/                ← progress, stop reports, autonomous log
├── 2b_handoff/                 ← generated discovery packages; immutable runs
├── api-contracts.md           ← interfaces between parallel stories
├── ground-file.md             ← validated assumptions
├── state.json                 ← state machine
└── <stage>/findings.json      ← review history beside its phase artifacts

src/**/agent.md                ← local; NEVER injected
```

### Spawn Tiering (decides whether a worker gets a context file at all)

Without tiering, the budget multiplies with the spawn count (an overnight
run = dozens of spawns, most of them micro-fixes). Therefore the spawn
class decides first, then the agent type:

| Tier | Spawn class | Context file |
|---|---|---|
| 0 | Micro-fix (1 finding, 1 AC, 1 build error) | **NOTHING** — the spawn prompt contains the finding verbatim + file paths + possibly an agent.md pointer. It needs nothing more. |
| 1 | Story implementer (whole US) | one story file: type-scoped pack (matrix below) plus the story slice |
| 2 | Reviewer/QA personas | PRODUCT.md + review-checklist by path + review criteria + diff scope; design system by path for ui-audit |
| — | Explore/scout spawns | nothing (read-only, own assignment) |

Implementation: **the tier is encoded in provider-neutral role
metadata** (`micro-fixer` = tier 0, `implementer`/`frontend-`/
`backend-implementer` = tier 1, `reviewer-*` = tier 2). Claude gets that
metadata as `.claude/agents/skillchain-*.md` (rewritten by every `compile`; the
text says "read the file named in the spawn prompt"); Codex lanes read the
same file named in the lane prompt. The compiled worker file is the
cross-provider source of truth, so provider differences cannot change what
context a role receives.

### Context Matrix (Tier 1, type-scoped)

What each tier-1 role receives is its manifest's `inject` list — the
curated docs by role (design system only for frontend and full-stack
work, the security baseline only where server code is touched), the
wave's compiled PROJ-architecture view and own-wave contracts, the ground
file, and the verbatim story slice under `## Your Story` — enforced by
the compiler, so the matrix lives in exactly one place:
[manifests/roles/](claude/skills/5_executing/manifests/roles/); the
section order of a compiled file in
[how-it-works.md](docs/how-it-works.md#what-a-worker-file-contains). The
minimalism rules are part of the implementer role manifests (§7) and so
of every tier-1 file; prior-wave context is a short orchestrator summary; folder `agent.md`
follows the reading protocol below and is never injected.

**Redundancy rules (overlap costs double):**
- `ground-file.md` contains ONLY assumptions that are not yet in
  `docs/` — whatever is validated and has lasting value migrates into
  ARCHITECTURE/GUIDELINES via curation and is removed from the ground
  file.
- The PROJ architecture references the baseline, never repeats it; its
  implementer view is compiled (decision and key-flow Summaries filtered to
  the wave's PRDs), never hand-written as a second file. Projects planned
  before Summary lines existed fall back to `architecture-delta.md`, else the
  whole file unfiltered (no migration required).
- `api-contracts` are scoped per wave/US, not injected as a whole-PROJ
  file.

**Budget enforcement (instead of budget intent):**
- The context compiler counts the role context of every file (the story
  slice is reported, not capped). `compile` and `check` fail if a role
  exceeds its manifest budget (~2–7k tokens) → condense first, then start.
- File caps (PRODUCT.md "half a page" and the per-file line limits, all
  defined once in the header of
  [curation.sh](claude/skills/7_documentation/scripts/curation.sh);
  `chain check caps --help` prints them) are checked as a hard gate in the
  P7 curation — otherwise the curated docs grow unnoticed until every
  session gets more expensive.

**Never injected:** whole PRDs, wave plans of other stories,
progress.md, complete SKILL.md texts (today's biggest waste in
Skill 5 — granular `references/` instead of whole skills). New skills
(`8_delivery` etc.) keep their SKILL.md lean and move detail into
`references/` that only the relevant phase loads.

### agent.md Protocol (Layer 4)

- **Read:** before the first edit in a folder: read `agent.md` there +
  in the nearest feature-level ancestor (max 2 files — not all parents
  up to the repo root; mandatory in the implementer template).
- **Write:** immediately when a learning occurs, at the DEEPEST
  applicable level: only this folder → folder agent.md; feature →
  feature agent.md; project-wide → AGENTS.md candidate; defect →
  findings.json.
- **Format:** Gotchas / Patterns That Work Well / Dead Ends (as today),
  every entry with date + commit SHA. Capped per file — beyond
  that, curate first, then append.
- **Status:** hints, not rules ("verify before you rely on it"). Rules
  come from docs/ and AGENTS.md.

---

## 6. Branching & Execution Model

**Dual-model concurrency is the DEFAULT; concurrent writes are not.**
Every model-dependent phase starts Claude and Codex lanes together.
Mode 1 keeps one write owner while the other lane independently prepares
tests, risks, or review input. This gains provider diversity without
checkout races. The single-writer invariant holds at the PROCESS level:
exactly one CLI process owns a checkout at a time — subagent teams
INSIDE that process (Mode 2) are today's proven Skill 5 model and stay
cheap. Multiple writer PROCESSES (Mode 3) remain evidence-gated because
they add worktrees, merge discipline, and per-worktree infrastructure.

```
main
└── proj/PROJ-X                     ← PROJ branch = the eventual PR
    ├── Mode 1 (DEFAULT): paired Claude + Codex lanes
    │                               → one writer, one read-only peer per story
    │                               → roles may swap; direct commits + wave tags
    ├── Mode 2: parallel wave, file-disjoint stories
    │                               → agent team in the writer lane's
    │                                 SHARED checkout (today's Skill 5
    │                                 model, no worktrees); peer lane
    │                                 stays read-only
    └── Mode 3 (OPT-IN, Stage 4): parallel writer processes, overlap risk
                                    → 1 worktree + branch per story
                                    → merge gate: merge back in dependency order
```

### Execution modes

- **Mode 1 — paired lanes (DEFAULT):** stories are written one after
  another on the PROJ branch, but Claude and Codex run concurrently.
  `state.json` assigns one provider as writer and the other as read-only
  peer for each story; the peer prepares test/risk input, then performs
  the provider-opposite review. Roles may swap at story boundaries. No
  worktrees or merge gate are required.
- **Mode 2 — shared-checkout parallelism (cheap middle tier):** the
  planner may mark a wave parallel ONLY if the stories' file sets are
  disjoint **and** its runtime constraints are safe or have a named lead
  owner. The stories then run as an agent team INSIDE the writer lane's
  process, in the shared checkout. The lead owns shared resources plus
  progress, staging, and commits; the peer lane stays read-only for the
  whole wave. No branches or merge gate, near-zero extra machinery; the
  single-writer-process invariant is untouched.
- **Mode 3 — isolated writer processes (OPT-IN, evidence-gated):**
  built in Stage 4 only if telemetry shows Modes 1/2 miss the nightly
  window. One worktree + story branch per writer lane (possibly one
  per provider). It adds the semantic merge gate and contract-driven
  conflict resolution below.

### Mode 3 mechanics (only when activated)

- No wave branches (three levels = overhead without benefit; the
  wave-gate script marks the boundary).
- **Worktrees are managed MANUALLY** (not via `isolation: "worktree"`):
  the orchestrator creates them
  (`git worktree add ../wt-us2 -b proj/PROJ-X/us-2`), and the spawn
  prompt sets the working directory absolutely ("work exclusively in
  <path>"). Reason: the built-in `isolation: "worktree"` is temporary
  with auto-naming/auto-cleanup — the merge gate needs named,
  predictable branches, control over npm install/ports per worktree,
  and a defined harvest point.
- **Parallelism cap: 3 worktrees** (framework.config; adjust via
  telemetry). Waves with more parallel stories are processed in batches
  of 3.
- **Order per parallel wave:** Outer Ralph stays wave-scoped; in Mode 3
  it runs per worktree (cwd = worktree, before the code is merged) →
  merge gate → wave gate ONCE on the merged PROJ branch. Sonar runs once
  per PROJ at PROJ end, not per wave (§7).
- Mode 3 uses a semantic **merge gate**: merge in dependency order, fix
  trivial conflicts, escalate semantic ones. Additionally: **union merge of
  the agent.md files**.
- **Gotcha channel:** agent.md is NOT enough across worktrees (isolated
  checkouts — invisible until merge), and agent-team messaging does not
  span separate CLI processes. Across worktree lanes, immediate
  broadcasts therefore run over a RUNNER-OWNED shared gotcha file
  (append-only JSONL at a path outside all worktrees, written via a
  helper script, read by every lane before each story); agent.md is
  joined at the merge gate. Within a Mode 2 team (one process),
  agent-team messaging works as today.
- Semantic conflicts between parallel stories = planning error
  (missing contract) → feedback into the P3/P4 templates.
- **Open for Stage 4 (only if Mode 3 is activated):** DB strategy,
  npm install strategy, port allocation per worktree. Container-based
  answers exist in Appendix A (ideas 1, 2, 7) — Docker strategy itself
  is developer-owned and out of scope.

### Always in place (independent of mode)

The PROJ branch (the PR needs it), rescue branches, tags as wave
boundaries, and the throwaway worktree for the P8 conflict probe —
all trivial, deterministic git.

---

## 6b. Symmetric Claude + Codex Mapping

The framework owns a provider-neutral phase contract. Thin adapters map
that contract to each CLI; provider-specific plugins are accelerators,
not the source of workflow semantics.

| Concept element | Claude adapter | Codex adapter | Shared contract |
|---|---|---|---|
| Headless lane | `claude -p` | `codex exec` | prompt file in, JSON/JSONL result out |
| Background process | shell child process | shell child process | runner starts both, waits for both, captures exit/status |
| Type-scoped context | worker file path in the spawn prompt | worker file path in the lane prompt | same compiled worker file |
| Agent role | `.claude/agents/*.md` | Codex skill/agent metadata | role, tools, write scope, budget |
| Minimalism | role manifest body | role manifest body | same byte-identical manifests; the Ponytail plugin was retired 2026-10-26 |
| Cross-review | OpenAI `codex-plugin-cc` pattern | Codex-facing `claude` skill pattern | provider opposite to `author_provider` |
| Wave-gate enforcement | optional external PreToolUse hook (`~/.claude/hooks/wave-gate-enforcer.js`, not shipped or installed by this repo) as defense-in-depth | prompt contract (no verified hook equivalent) | RUNNER-owned: the next wave/lane is not started until `chain gate wave` exits 0; hooks only harden this, they don't carry it |
| Gotcha broadcast | agent-team messaging within one process | agent-team messaging within one process | across processes: runner-owned shared JSONL file (§6) |
| Worktrees / rescue / conflict probe | plain git | plain git | runner owns all git lifecycle |
| PR + CI polling | `gh` | `gh` | deterministic P8 scripts |
| Morning notification | provider hook when available | provider hook when available | report file is canonical; notification is best-effort |
| Status | provider UI adapter | provider UI adapter | `state.json` is canonical |

**Stage 1 verification spike (~1h, one dummy artifact):** launch
`claude -p` and `codex exec` concurrently from the runner, enforce
read-only tools, capture valid JSONL from both, attribute provider and
author correctly, and prove cancellation/timeout kills both process
trees. This is a release gate for Stage 1.

**Mode 2:** no hook is involved — every teammate gets the path of its
compiled worker file in its spawn prompt.

**Stage 4 verification spike (~1h, 2 dummy stories):** direct Claude
and Codex writer lanes into named worktrees, merge file-disjoint changes,
then exercise one intentional semantic conflict plus npm install and
port allocation. Mode 3 stays disabled until this passes.

---

## 7. Tooling

### Required CLIs & Tools (the P0 preflight checks exactly this list)

| CLI/Tool | Purpose | Required |
|---|---|---|
| `git` | branching, worktrees, merge gate, rescue, conflict probe | ✅ hard |
| `gh` | create PR, `gh pr checks` polling (P8) | ✅ hard |
| `claude` | Claude phase lane + provider-opposite review via `claude -p` | ✅ hard |
| `node` | hooks (the optional external wave-gate-enforcer) + scripts (ledger, rendering) | ✅ hard |
| `jq` | `chain gate wave`, `chain findings`, `chain state` | ✅ hard |
| `coderabbit` | wave review (`--agent --base-commit`) | ✅ hard (gate component); skipped, logged, when `wave-gate-config.json` sets `coderabbit.enabled: false` |
| `codex` | Codex phase lane + provider-opposite review via `codex exec` | 🟡 preferred, degradable — missing/unauthenticated → single-provider run with model-opposite review, flagged in report + PR body, never silent |
| `agent-browser` | smoke tests in the wave gate, browser E2E in P6 | ✅ hard for frontend waves; backend-only: unused |
| `sonar_cmd` dependencies | project-defined local scan + secrets check, once per PROJ at the PROJ-end Quality Gate — no wave gate runs it | ✅ hard through the configured command |
| `supabase` (drift check) | `migration-drift-check.sh`: compares the shared local DB's applied migrations against this worktree's own `supabase/migrations/` | 🟡 only if Supabase in the stack; hard-fails P0 preflight and every wave gate on drift |
| `sonar` | optional additional PROJ-end Sonar CLI/API stream | 🟡 skippable with explicit PROJ-end disposition; never skips `sonar_cmd` |
| `sonar-scanner` | full quality gate at PROJ end (P5 Quality Gate) | 🟡 skippable with log entry |
| `supabase` | migrations, types, local instances (if the product uses Supabase) | 🟡 only if Supabase in the stack |
| Jira access (Atlassian MCP or CLI/REST) | PRD intake Mode B (P2d) + status sync-back | 🟡 TODO — only for Mode B (Stage 3); Mode A (local PRDs in specs/) needs nothing |
| `npm`/`pnpm` | build/tests; pnpm decision for worktree installs is made in Stage 4 | ✅ hard (project-dependent) |

Preflight behavior: hard tools missing → stop condition (§8), never
skipped silently. Skippable tools missing → skip with a log entry in
progress.md/state.json. Auth is checked too (`gh auth status`,
`sonar auth status`/`SONAR_TOKEN`, CodeRabbit login), not just
`command -v`.

### CodeRabbit CLI
- `coderabbit review --agent --base-commit <sha>` — JSON output for
  agent loops; review scope = wave diff.
- **Budget: Pro plan + usage add-on available** → the rate limit is not
  a design constraint. Review nevertheless stays per WAVE (not per
  story): less noise, one diff scope per gate, per-file costs stay
  visible. The waiting rule in §8 is only a fallback for outages.
- The `.coderabbit.yaml` preflight (exists in Skill 5) remains.

### Sonar — One Stage, PROJ end only
- **Decision:** the project-defined `sonar_cmd` (the repo's real scan entry
  point) runs ONCE per PROJ at the PROJ-end Quality Gate, from the
  persistent PROJ worktree, against the whole assembled diff — so it covers
  every wave's cumulative changes; no wave gate runs it. The same run feeds
  the quality-gate CLI/API stream (issues, coverage, duplication) via the
  `sonar-cli` skill.
- **Environment: SonarQube Cloud, already set up** (org, token, project
  config present) — the P0 preflight only verifies auth instead of doing
  setup.
- Skip is allowed only when the Sonar CLIs are unavailable or the project
  has no Sonar config; `chain quality seal` rejects any other skip, so the
  gate fails closed wherever the project is Sonar-configured. Survivors of
  the bounded fix rounds are carried forward to QA, never blocking. Gate
  order, preflight, rounds and evidence:
  [quality-gate.md](claude/skills/5_executing/references/quality-gate.md).

### Claude + Codex CLI Adapters
- `claude -p` and `codex exec` are first-class phase lanes. The runner
  starts them concurrently with provider-specific read/write tool
  restrictions derived from the same role record.
- Cross-review routes to the provider opposite `author_provider` when
  both are available; joint artifacts receive two independent read-only
  reviews. Fallback: model-opposite within the surviving provider (§4).
- The framework owns prompt templates, output normalization, budgets,
  timeouts, cancellation, and ledger integration. External skills and
  plugins are pattern sources or optional UX adapters, not state owners.
- P0 checks both auth states and performs a bounded live probe. `claude`
  is hard (it hosts the chain). `codex` missing or unauthenticated does
  NOT block: the run enters degraded single-provider mode — Mode 1's
  peer lane and all cross-reviews (the six-persona QA fallback excepted, see
  `cross-review/SKILL.md`) fall back to the strongest Claude model
  that is not the author's (rank `fable opus sonnet`; it must differ from the
  writer's model), recorded in `state.json` and
  flagged in the morning report and PR body.

### Minimalism rules (Ponytail retired 2026-10-26)

Until 2026-10-26 the minimalism ladder came from the third-party Ponytail
plugin, installed in mode `full` on every active provider and gated in the
P0 preflight (`chain check ponytail`). It was retired: it injected ~60 lines
of persona, output rules and an artifact-level Don't catalog into every
subagent on both providers — reviewers, QA and doc writers included — and
most of its useful content already lived in our briefs (YAGNI,
`## Dependencies`, the registry rule, the Simplicity Gate). Plan:
`specs/_plans/2026-10-26-dos-donts-placement-and-ponytail-retirement.md`.

What replaces it, chain-owned and byte-identical across providers:

- **Implementer roles** (`implementer`, `frontend-implementer`,
  `backend-implementer`): the `## Minimal by default` section of the role
  manifest — reuse before writing, listed dependencies only, no abstraction
  without a second current user, no scaffolding for later, no silent
  fallbacks, and never minimized validation/security/accessibility.
- **`micro-fixer`** and `bugfixing`: trace the flow before the smallest
  diff; grep every caller and fix once where they all route through.
- **Debt markers:** the `debt:` comment convention (ceiling + upgrade path)
  replaces `ponytail:`; `chain findings harvest` reads both for one release.
- **Leftover installs:** `check-setup.sh` warns while the plugin is still
  installed (it would still inject into every subagent) and `uninstall.sh`
  offers its removal for one release. `install.sh` never installs it.
- `.context.ponytail` in `state.json` is deprecated: nothing writes it; the
  schema keeps it so older runs validate.

Not carried over on purpose: output rules ("code first, three lines"), the
persona framing, "boring over clever", hardware calibration.

### Scripts & Templates — the Deterministic Output Layer

**Governing rule: the LLM decides, scripts render.** Agents write ONLY
into structured data (`state.json`, `findings.json`) through tested
helpers. Every human-facing artifact — PR body, morning report, stop
report, progress sections, Jira comments (Mode B) — is rendered from
that data via templates by scripts. The LLM never freehands these
documents. This is what makes output consistent across runs, phases,
and model versions: same data in → byte-identical structure out.

**Delivery convention:** every deterministic step is a script inside
its skill's `scripts/` directory, every rendered artifact has a
template inside the skill's `templates/` directory. P0 setup copies
both into the repo (`scripts/`, `templates/`) and commits them —
versioned with the repo, testable outside sessions, identical behavior
on every machine. `chain gate wave` is the existing proof of the pattern.

**Schemas:** `state.schema.json` and `findings.schema.json` ship with
the framework. `state.sh` and `findings.mjs` validate on every write —
an agent writing a malformed record fails loudly at write time, not
silently at render time.

**Evidence retention boundary:** CodeRabbit raw and normalized JSONL is retained
per gate attempt because it directly drives the local decision. CI and Sonar
evidence remains authoritative in those systems. Cross-review stores validated
normalized findings, not complete model responses that may carry sensitive
prompt context. The framework does not indiscriminately archive every external
response.

**Inventory:** every script is reached through one dispatcher, `chain
<verb> [<sub>]`, and belongs to exactly one of five kinds — Record (the only
writer of one machine file), Gate (exit code + report), Renderer (data →
document, never writes state), Environment (worktree, helper sync), Review
(opposite-provider reviewer). `chain --list` prints the current table and
[how-it-works.md](docs/how-it-works.md#the-five-script-kinds) explains it;
the templates ship next to their scripts in each skill's `templates/`
directory. Free-form LLM text still exists — analysis, findings
verification, architecture prose, agent.md learnings — but it always lands
INSIDE a template frame or a schema field, never as an unstructured
document of its own.

### Findings Ledgers (`<stage>/findings.json`)
Each review step stores its ledger in its own subfolder; free-standing reviews
outside a PROJ report findings without creating files. Fixed and deferred
records remain in the owning ledger. All writes go through `chain findings`.
One record per finding — source, location, category, normalized severity,
status (`open` / `fixed` / `deferred` / `false-positive`), fix commit,
debt-marker reference — written only through `chain findings`, which
deduplicates across sources. The PR body and progress.md are generated FROM
this, not maintained by hand. Contract:
[findings.schema.json](runner/schemas/findings.schema.json); the three
machine files and their single writers in
[how-it-works.md](docs/how-it-works.md#three-files-three-writers).

---

## 8. Autonomy Policy (Overnight Runs)

After Checkpoint 1 the process runs without user interaction up to the
finished PR for one PROJ per `run-phase.sh auto` call. Running several
approved PROJs in sequence (one Checkpoint 1 approving several plans, then a
queue) is the intended direction but **not implemented**; see Stop Behavior.

### Escalation Rules (replace all "ask the user" spots)

| Situation | Behavior |
|---|---|
| Medium/Low findings & bugs | auto-defer: debt marker + ledger, decision at Checkpoint 2 |
| Outer Ralph still red after its four recovery stages (or an AC proves invalid/contradictory) | blocked-run evidence path → stop condition; the AC is never weakened or shipped as a "known gap" |
| Wave gate red | verbatim output to a follow-up worker, then rerun the same gate; exit 76 waits for the declared external prerequisite, exit 73 needs resource diagnosis; repeated failures → blocked/escalation path with the attempt history |
| Critical bug survives 3 fix attempts | stop condition |
| Semantic merge conflict (parallel) | 1 resolution attempt with the contract as reference; unresolved → stop condition |
| Tool missing / auth broken / env broken | stop condition (never skip silently; the PROJ-end `sonar_cmd` is mandatory) |
| Rate limit exhausted (CodeRabbit) | wait until the window frees up, max 1h; then stop condition |
| Security-critical (secrets in code, auth bypass) not auto-fixable | stop condition, do NOT commit the wave |

### Stop Behavior ("bad problems")

On a stop condition the run is NOT simply aborted but parked in a
controlled way: uncommitted work is secured on a `rescue/PROJ-X-<timestamp>`
branch, `state.json` goes to `blocked` with the exact cause, and a stop
report is rendered (what happened verbatim, state when parked, cleanup
list, recommended next action). Open worktrees and dev servers are
documented, not deleted — they are evidence; the persistent PROJ worktree
is retained with its path and the safe P8 resume command, and only a
successful P8 may remove it after exact-head green CI. A multi-PROJ queue
is **not implemented**: `run-phase.sh auto <X> <theme>` drives exactly one
PROJ and stops with it. The intended design, for a future queue, is that a
PROJ-local failure lets the next PROJ start while an environment failure
(env/tools) ends the whole run. The stop policy is in
[runner/README.md](runner/README.md#invariants-the-runner-owns), the report
frame in
[stop-report.md.tmpl](claude/skills/5_executing/templates/stop-report.md.tmpl),
the guarded cleanup in
[8_delivery/SKILL.md](claude/skills/8_delivery/SKILL.md#5-seal-the-autonomous-part).

### Morning Report

The cross-PROJ report (`specs/morning-report-<date>.md`) is rendered from
`state.json` + `findings.json` by `chain render report morning specs` —
per PROJ status, PR link, gate/QA summary, deferred debt, known gaps,
provider/model degradations, stop reports, cleanup list — and is the first
thing the human reads in the morning, before the PRs.

**Delivery decision:** a successful run ends in P8 with the PR open
(waiting for merge) or the worktree removed; in both cases the runner does
NOT render the report, because the filesystem must stay clean for the
post-merge cleanup. It prints and best-effort notifies a one-line summary
instead (final CI head, PR, post-merge rerun command); the durable state is
on the retained PROJ branch and in the PR body. The file is rendered at run
end only when neither applies, and otherwise on demand. A stopped run always
renders its stop report; notification failure never loses state. Handoff
and launch:
[unattended-handoff.md](claude/skills/5_executing/references/unattended-handoff.md).

---

## 9. Differences from Today's Chain

| Change | Replaces/extends |
|---|---|
| P3 reads/writes the curated ARCHITECTURE.md, produces a delta | Skill 3 (per-PROJ architecture without a baseline) |
| P0 setup with compiled worker context files | FIRST-ACTION block + if/else context logic in Skill 5 |
| Paired Claude + Codex lanes by default; worktrees for concurrent writers | one host process plus same-host subagents in a shared checkout |
| required project `sonar_cmd`, secrets caught before merge | Sonar only at PROJ end (this concept originally proposed running `sonar_cmd` in every wave gate; the shipped implementation kept it PROJ-end-only — see §7) |
| Findings ledger as the central fix queue | 4 separate finding streams |
| Minimalism ladder in implementer prompts | only the Ken review at PROJ end (Ken stays as the net) |
| Folder agent.md with protocol + curation | agent.md per feature only, without curation |
| Docs + curation BEFORE the PR (P7 before P8) | docs after the merge point |
| P8 delivery skill | missing entirely |
| 2 declarative checkpoints + autonomy policy | scattered "ask the user" spots |
| Stop report + morning report | abort without a defined parked state |
| state.json + statusline | only progress.md, resume via guessing |
| Fresh Claude + Codex lanes per phase (host-neutral runner) | one long host session with /compact points |
| Spawn tiering (micro-fixes without a pack) | the same context for every spawn |
| Dedup/rendering as scripts | ledger/report work in the LLM context |
| Provider-opposite Claude ↔ Codex review of requirements, QA evidence, pre-mortems, and curated docs | same-model persona review only; docs content never reviewed |

Unchanged and explicitly preserved: the current pre-PRD Skills 1–2
flow, both delivery tracks, immutable generated `2b_handoff/` packages,
the Ralph principle of deterministic verification (now one bounded Inner
Ralph per worker plus a wave-scoped Outer Ralph with four recovery stages),
the TDD cycle, the wave-gate script principle,
the read-only persona QA, and
agent-browser smoke tests.

---

## 10. Implementation Roadmap (each stage usable on its own)

1. **Stage 1 — dependency-complete overnight core:** minimal
   `4a_checkpoint` for CP1 approval + `4b_setup` for P0, autonomy policy
   (preserve read-only Skill 6, add the P6 controller/fix loop, unify
   escalation rules, stop report, morning report), P8
   delivery (including the CP2 reconcile loop for PR comments), findings
   ledger, schemas/helpers, and the **host-neutral dual-lane phase
   runner**. The release gate launches `claude -p` and `codex exec`
   concurrently, proves provider attribution/read-only peer review,
   and verifies timeout/cancellation. Update `chain-guide` and Skill 5
   to route to this runner; remove every `autonomous-execution`
   reference. With these dependencies in the same stage, the existing
   full-chain flow can run unattended without compact roulette. The
   discovery track remains outside the runner.
2. **Stage 2 — bootstrap & full context system (now, while cheap):**
   `0b_intake` skill (scan & draft with provenance markers → developer
   interview → reconcile via `4a_checkpoint` → seal; see §3), extend
   `4a_checkpoint` from the Stage 1 minimum to bootstrap reuse, extend
   `4b_setup` with the context compiler (one file per worker; the first
   design's provider projections and SubagentStart injector are retired —
   the path in the spawn prompt replaces them; manifest schema following
   the claude-skills frontmatter taxonomy),
   the minimalism rules in the role manifests (§7), agent.md protocol +
   P7 curation, and the symmetric `cross-review` mechanism. The current
   producing skills now wire automatic concept/architecture/plan reviews and
   required Requirements/P6/P7 gates. The optional focused `bugfixing` workflow
   is also built outside the numbered chain.
3. **Stage 3:** P3 runner rework (baseline/delta) and deeper pre-mortem
   orchestration. The skill-level cross-review handoffs already exist; this
   stage concerns their runner integration and richer risk inputs.
   **Jira intake Mode B = TODO within this stage:**
   `2d_prd-import` (fetch, snapshot, ID mapping, AC check, sync-back;
   mechanism decision MCP vs. CLI/REST) — built only after the chain
   has been tested end-to-end in Mode A (local PRDs).
4. **Stage 4 (OPT-IN, evidence-gated):** built only if telemetry from
   Stages 1–3 shows Modes 1/2 missing the nightly window. Verify spike
   (§6b) → worktree branching + semantic merge gate (Mode 3),
   parallelism cap, DB/install/port strategy. Until then, Mode 2
   (shared-checkout team inside the writer lane, file-disjoint waves)
   is the only parallelism beyond the paired lanes — one write-owning
   process at a time throughout.
5. **Stage 5:** statusline, telemetry, benchmark harness.
   (Packaging/marketplace: deliberately postponed — only when
   distributability becomes a topic again.)

---

## 11. Decisions

*All concept questions are decided:*

| Question | Decision |
|---|---|
| Distribution | private for our own product; packaging later |
| Autonomy | maximally autonomous after CP1, overnight; stop policy §8 |
| Bootstrap timing | now, while the codebase is small |
| Platform | GitHub + CI given; P8 polls via `gh pr checks`; dual-provider (Claude + Codex) PREFERRED, degradable to single-provider with model-opposite review — `claude` hard, `codex` degradable |
| CodeRabbit | Pro + usage add-on; review per wave, limit not a constraint |
| Sonar | SonarQube Cloud, already set up (org/token/project) |
| Execution mode | paired Claude + Codex lanes are the DEFAULT (one writer, one read-only peer); Mode 2 (shared-checkout team inside the writer lane, file-disjoint waves) as the cheap middle tier; Mode 3 (worktree writer processes + merge gate) opt-in, built only on telemetry evidence (Stage 4). Cost stays bounded via model tiering per role |
| Parallelism cap | 3 (applies to Modes 2/3; framework.config, adjustable via telemetry) |
| Skill numbering | dock on: `0a_product-vision`, `0c_bootstrap`, `0b_intake`, `2d_prd-import`, `cross-review`, `8_delivery`; CP1 + P0 are subskills of `5_executing` |
| PRD source | TWO modes, downstream identical. Mode A (DEFAULT): PRDs written directly into the repo (existing structure) — the new chain is tested in this mode first. Mode B (TODO, Stage 3): Jira import, created/enriched via Teklens (teklens.ai); local snapshot = working truth per run; Jira keys in commits/PRs; sync-back |
| PRD ownership | PM PRDs are raw input: developers enrich with technical stories, re-cut into buildable PRDs (in Jira for Mode B), and OWN the selection of the story set sent into the agentic loop — the framework checks AC quality, not scope |
| Morning report | one-line summary + best-effort notification at run end; file in `specs/` rendered on demand (or at run end when P8 left neither an open PR nor a removed worktree) |
| Minimalism ladder | six `## Minimal by default` rules in the implementer role manifests (plus two micro-fixer rules), chain-owned and byte-identical across providers; the Ponytail plugin was retired 2026-10-26 (§7) |
| Context pack manifest | schema following the claude-skills frontmatter taxonomy, defined when building the compiler (Stage 2) |
| Cross-model review | symmetric provider-opposite review via our thin `cross-review`: Claude-authored → Codex, Codex-authored → authenticated isolated Claude with validated structured output, joint → both independently; required for Requirements/P6/P7 and automatic on saved concept/architecture/plan outputs; conservative default input cap, explicit diff omissions and Claude 10 MB stdin failure; any permitted model-opposite fallback is flagged, and same-model review never satisfies the gate (the six-persona QA fallback excepted, see §4); findings → ledger, blocking per §8 |
| Focused bug repair | `bugfixing` stays outside the feature chain: reproduce first (real browser for UI), trace code cause + test escape, prove a regression test red before the fix, dispatch a micro-fixer, and stop after at most three Ralph repair attempts; CodeRabbit/Sonar are proportional existing gates, not new dependencies |
| Structure quality | Gate-driven, no "cleaner" agent: a check that fails beats a prompt that dilutes. Optional project-supplied `complexity_cmd` / `arch_rules_cmd` are wave-gate checks whose failures take the Outer Ralph recovery path; thresholds live in the tool's config, absent = skipped, and reviewers do not re-flag what the tool measures. Contract: [wave-gate-config.md](claude/skills/4_writing-plans/references/wave-gate-config.md) |
| Test quality | Optional `mutation_cmd` runs once per PROJ in the Quality Gate, scoped to the feature diff. Late is safe because survivors only get tests-only fix rounds, which cannot change production code; structure must be early because it compounds. Survivors are carried forward like Sonar's; QA assigns severity. Contract: [quality-gate.md](claude/skills/5_executing/references/quality-gate.md) |
| P6 QA/fix ownership | Skill 6 is a strictly read-only finder. The P6 phase controller deduplicates and verifies findings, dispatches tier-0 fix lanes, and requires fresh provider-opposite QA re-verification; three failed Critical/High repair attempts trigger the stop policy |

New questions arise during the detailed planning of each stage and are
decided there — no longer here.

---

## Appendix A — Docker Ideas (OUT OF SCOPE — developer-owned)

Docker/container strategy is deliberately NOT part of this concept.
Developers evaluate and, where useful, implement it. The ideas below are
handed along because each one directly supports a pain point of the
agentic workflow — take them or leave them.

1. **One compose project per worktree (solves the Stage 4
   port/DB problem).** Give every story worktree its own
   `COMPOSE_PROJECT_NAME=proj-x-us2` and env-driven port mapping
   (`PORT=0` / templated ports). Three parallel worktrees then get three
   fully isolated stacks (app + DB) with zero manual port bookkeeping —
   the merge gate tears them down. This is the cleanest answer to the
   open "DB/install/port strategy" item in §6.

2. **Ephemeral DB per story.** A fresh Postgres/Supabase container per
   worktree, migrations applied from zero. Ralph's AC runs become
   deterministic (no state bleed between iterations or between parallel
   stories), and migration collisions between parallel stories surface
   at the merge gate instead of corrupting a shared dev DB. Until this is
   built, `migration-drift-check.sh` (§7) is a lighter, shipped mitigation:
   it does not prevent the shared DB from drifting, but it stops any
   worktree from silently trusting a schema a sibling worktree already
   changed underneath it.

3. **Dev container as the environment contract.** A
   `devcontainer.json`/base image that pins node, pnpm, jq, and the
   scanner CLIs makes the §7 preflight trivially reproducible: a new
   worktree or a new machine is guaranteed to pass the same preflight.
   Env drift is one of the classic overnight-run killers.

4. **Sandbox the overnight run itself.** Run the phase runner
   (headless `claude -p`) inside a container with a mount limited to
   the repo and an outbound network allowlist (GitHub, Sonar,
   CodeRabbit, npm). Autonomous execution with
   `--dangerously-skip-permissions` has a much smaller blast radius
   inside a container than on the host — the rescue-branch guarantee
   then also holds against environment damage, not just git state.

5. **CI parity via a shared image.** Use the same image for the local
   wave gate (build/tests) and the GitHub Actions workflow. "Green at
   the gate" then predicts "green in CI", which shrinks P8's
   CI-fix loop to near zero.

6. **Smoke-test stack as a compose profile.** Dev server + DB +
   agent-browser dependencies as a profile the wave gate starts and
   tears down; ports injected per worktree (see idea 1).

7. **Shared caches across worktree containers.** A named volume for the
   pnpm store and build caches, mounted into every worktree container —
   parallel stories then don't pay 3× install time (the npm-install
   question from §6 dissolves).

8. **PR preview container (CP2 support).** Build an image per PR so the
   human reviewer can click through the running feature during the
   morning review — turning Checkpoint 2 from diff-reading into product
   review.

If developers adopt ideas 1–3, the Stage 4 open items in §6
(DB/install/port strategy) are essentially answered; the framework
itself stays container-agnostic either way (everything runs through the
same CLIs and scripts, containerized or not).
