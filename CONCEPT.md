# Agent Workflow Framework — Concept

**Status:** Draft v0.19 — under iteration (leading version; the German
KONZEPT.md is frozen at v0.9)
*(v0.4: context-economy review — session-per-phase, spawn tiering,
scripts instead of LLM for deterministic work, budget enforcement)*
*(v0.5: git/subagent review — tiering via agent types, manually managed
story worktrees, gotcha channel for parallel waves, Claude Code mapping §6b)*
*(v0.6: ponytail adopted as a ready-made plugin — decided; manifest schema
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
*(v0.16: cross-model review — skill `3a_cross-review`: Codex CLI as an
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
**Date:** 2026-07-14
**Basis:** the repository's aligned Codex + Claude SkillChain 0–7
(`codex/skills/`, `claude/skills/`) at the current main branch

**Settled decisions (v0.2):**
- The framework is optimized against our own product; distributability
  maybe later → no early packaging/skill CI, stay lean.
- After Checkpoint 1, as autonomous as possible; overnight runs are the
  normal case → autonomy policy in §8; no "ask the user" between the
  checkpoints.
- Infrastructure is rudimentary at first (CI optional), the codebase will
  potentially become large → do the intake bootstrap NOW while it is
  cheap; context budgets and curation are designed for growth.

---

## Executive Summary

**What:** An agent workflow framework built on the existing
SkillChain 0–7 that turns PRDs into production-ready, reviewed,
documented pull requests fully automatically — including overnight.
PRDs arrive via one of two intake modes: written directly into the repo
(the existing structure — the DEFAULT for the first runs) or imported
from Jira, where Teklens creates/enriches them (TODO, Stage 3; adds
status/PR-link sync-back). Downstream, both modes are identical. The human
intervenes at exactly two points: approving architecture + plan, and
merging the PR. Both checkpoints run as a structured reconcile loop
(`4a_checkpoint`): feedback is collected point by point, recorded in a
decision log, and written back into all affected artifacts in a cascade.
Everything in between runs autonomously; on defined stop conditions the
run is parked in a controlled way (rescue branch, stop report), and every
run ends with a morning report + push notification.

**How:** A host-neutral runner starts fresh Claude and Codex lanes per
phase and runs them concurrently wherever their work is independent
(handoff only via `state.json` and structured lane outputs — no compact
roulette). Concurrency of MODELS is the default; concurrency of WRITES is
not. One lane owns each artifact/file at a time, while the other produces
an independent proposal, test strategy, or review. User stories run in
dependency waves; every wave is checked by a hard gate
(ACs/tests, build, CodeRabbit review, Sonar secrets scan, browser smoke).
Mode 1 pairs both providers concurrently around one write owner;
file-disjoint stories may run as a shared-checkout team inside the
writer lane (Mode 2, cheap); isolated writer processes with worktrees
and a merge gate (Mode 3) are opt-in, enabled only if telemetry proves
the nightly window overflows. All review sources flow
into ONE deduplicated findings ledger with a single fix queue;
Medium/Low findings are automatically deferred as marked debt instead
of prompting the user. Pre-mortems and the curated docs additionally
pass provider-opposite adversarial review via `3a_cross-review`: Claude
reviews Codex-authored artifacts and Codex reviews Claude-authored
artifacts. Joint artifacts receive independent reviews from both lanes
before reconciliation, so an authoring model never grades its own work
alone. If a provider is unavailable, the run DEGRADES instead of
stopping: it continues single-provider, review falls back to
MODEL-opposite (a different model of the surviving provider — e.g.
Sonnet 5 reviewing Fable-authored artifacts), and the degradation is
flagged in the morning report and the PR body.

**Why it stays cheap:** Context is the most expensive resource. Hence:
curated half-page docs instead of full texts, injection only by spawn
class (micro-fixes get nothing), deterministic work runs as scripts
rather than through the LLM, and token budgets are enforced in the
preflight. Minimalism at code-writing time is delivered by the ponytail
plugin (decided). Dual lanes do NOT mean double flagship cost: every
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
           (4a_checkpoint:                               (reconcile loop for
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
                     │ pack    │  │  → wave gate  │  ledger  docs +  conflict
                     │ hooks   │  │ paired lanes  │  dedupe  curation probe,
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
   the implementer prompts (hook injection), not only in reviews at the
   end. Code that is never written needs no review.
4. **Context economy: as much as necessary, as little as possible.**
   Four mechanisms: (a) one phase = fresh Claude and Codex lanes, handoff
   only via `state.json` + file paths; (b) injection is tiered by spawn class —
   micro-fix spawns get NO pack; (c) everything deterministic (dedup,
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

The repository's existing pre-PRD flow is preserved unchanged. A PROJ
starts with `1_brainstorming`, optionally follows the UI branch
(`1b_visual-companion` → optional `1c_frontend-design` →
`1d_ui-mockup` → optional `1e_concept-sync`), and then runs
`2_requirements-engineer`. On the product-discovery track it may continue
through `2b_handoff-package` and `2c_review-reconcile`, then stops; P3–P8
never run. Only a full-chain PROJ enters P2d/P3 below. Existing generated
`8_handoff/` package runs remain immutable and are unrelated to the
`8_delivery` skill.

```
        EXISTING PRE-PRD FLOW (preserved)
        brainstorm → UI exploration/mockups when needed → requirements
              │
              ├── discovery track → Linear / 8_handoff package → STOP
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
              ▼ ◇ CHECKPOINT 1 (human, via 4a_checkpoint):
                reconcile loop → decision log → cascade updates
                into artifacts → state.json "approved" unlocks P0
  ┌───────────────────────┐
  │ P0  SETUP             │  branch, context pack, ground file, hook, preflights
  └───────────┬───────────┘
  ┌───────────▼───────────┐
  │ P5  EXECUTION         │  per wave: implement → Ralph → wave gate
  │     (loop over waves) │  dual-model lanes; single-writer rules (§6)
  └───────────┬───────────┘
  ┌───────────▼───────────┐
  │ P6  QUALITY & QA      │  findings ledger: collect → dedupe → fix
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

### First Run (Bootstrap) — Skill `0b_intake`

The first run on an existing product starts with a one-time intake,
owned by a dedicated skill. Its core principle: **extraction and
interview are two different sources, and the skill needs both.** Code
can tell you what IS; only the developer can tell you what is
INTENDED — product scope and non-goals, security requirements, and
which of two inconsistent code conventions is the rule going forward.
The intake is therefore a collaborative session with the developer,
not a batch job.

**Step 1 — Scan & draft (automated; spec-miner principle: Arch Hat +
QA Hat; `gen-component-registry.mjs` for the registry).** Produce first drafts of
all curated docs, with every statement carrying a provenance marker:

- `extracted` — derived from code/README/git history, with evidence
  (file references)
- `assumed` — plausible inference that needs developer confirmation
- `gap` — cannot be derived from code at all; must be asked

**Step 2 — Developer interview (the "together" part).** Work through
all `gap` and `assumed` items point by point (AskUserQuestion /
guided conversation), plus every detected **inconsistency**: "the
codebase handles errors via X in ~60% of cases and Y in ~40% — which
is the rule going forward?" The answer becomes a GUIDELINES rule; the
losing pattern becomes a known-debt note, not silently rewritten.

**Step 3 — Reconcile & seal** via the `4a_checkpoint` loop (decision
log; generated docs are hypotheses, not truth). Final docs must pass
the file caps (§5) — the interview output is curated, not dumped.

**Step 4 — Commit** as the initial curation baseline. From here on,
P7 curation owns all updates; `0b_intake` is re-run only as a
deliberate drift audit, never automatically.

**Files produced:** `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`
(+ `docs/architecture/` details), `docs/GUIDELINES.md`,
`docs/DESIGN-SYSTEM.md` (brownfield: extract tokens from the code; if
none exist, record a pointer to `1c_frontend-design` instead of
inventing one), `docs/components.md` (generated from the doc block above each
component export; the interview supplies the purpose lines no parser
can extract), the security baseline and test conventions, and an
initial `AGENTS.md`.

**Near-greenfield variant:** if there is almost no code yet, the
extraction step is thin and the interview carries the weight — same
skill, same output files, sourced from the concept/PRDs plus the
developer's answers.

**Timing:** The bootstrap happens AS EARLY AS POSSIBLE — the codebase is
still small today, so the intake is correspondingly cheap and the
validation manageable. From then on the curated docs grow organically
with every PROJ (P7 curation) instead of having to be reverse-engineered
against a large codebase later.

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
the chain format at `specs/PROJ-<X>-<theme>/3_PRDs/*.md` (user stories with
Given/When/Then + ACs). P3 onward never knows or cares where a PRD came
from.

**Mode A — local repo PRDs (DEFAULT for now):** PRDs are written
directly into the repo, as today — via Skill 2
(`2_requirements-engineer`) or by hand. No import step, no sync-back;
the files in `specs/PROJ-<X>-<theme>/3_PRDs/` simply ARE the snapshot. **The new
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
   (`specs/PROJ-<X>-<theme>/3_PRDs/*.md`, user stories with Given/When/Then +
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
   the CP1 reconcile (via `4a_checkpoint`) or played back as a Jira
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
2. **Draft the delta:** `specs/PROJ-<X>-<theme>/architecture-delta.md` — only the
   NEW decisions of this PROJ. References standing decisions instead of
   repeating them ("uses the standing auth decision; NEW: event queue
   for status transitions, because …").
3. **Pre-mortem:** automated review (the-fool modes: devil's advocate,
   pre-mortem, evidence audit) against delta + PRDs, PLUS a cross-model
   pass via `3a_cross-review` (below). Authorship is explicit:
   `state.json` assigns ONE provider as the delta author
   (framework.config; alternates per PROJ by default). The non-author
   lane starts from the same bounded input in parallel and produces an
   independent risk-and-assumption sketch — that sketch feeds the
   pre-mortem as input, it is not a second delta to reconcile. The
   non-author then delivers the blocking critique.
4. **Derive contracts:** `specs/PROJ-<X>-<theme>/api-contracts.md` — interfaces
   between soon-to-be-parallel stories are pinned down HERE, not guessed
   by implementers.

### Cross-Model Review Skill `3a_cross-review` (new)

Same-model review is an echo chamber: the model that made the
decisions, wrote the code, and curated the docs will grade its own
summaries as accurate. The-fool personas vary the PROMPT, but not the
provider — blind spots survive persona rotation. This skill is
symmetric: Claude-authored artifacts go to Codex (`codex exec`) and
Codex-authored artifacts go to Claude (`claude -p`). Both invocations
are headless, strictly read-only, and bounded. `state.json` records the
authoring lane for every reviewed artifact; a review from the same
provider does not satisfy the gate.

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

**Three call sites (analogous to `4a_checkpoint`):**

| Call site | Artifacts reviewed | Review focus |
|---|---|---|
| P3 pre-mortem | architecture-delta + PRDs | wrong/missing decisions, unstated assumptions, contradictions with the baseline |
| P4 plan review | wave plans + wave-gate-config + api-contracts | unsafe ordering, weak AC commands, missing contracts |
| P7 docs review | curated docs delta (+ full capped docs) vs. the PROJ diff | factual accuracy ("does ARCHITECTURE.md describe what was actually BUILT?"), stale claims, cap-gaming (shrinking docs by deleting true load-bearing statements) |

The P7 call site is the critical one: curated docs are injected into
every future implementer — a wrong statement there poisons every
subsequent PROJ. Hence BLOCKING, not advisory.

**Mechanics:** `cross-review.sh` renders the review prompt from a
template (mode + file list), reads `author_provider` from `state.json`,
and routes to `review-with-codex.sh` or `review-with-claude.sh`. Each
adapter normalizes its provider output into the same findings JSON-lines
contract → `ledger.mjs`. For joint artifacts the runner invokes both
adapters concurrently and deduplicates only after source attribution is
preserved. No new severity rules: Critical/High block phase completion
(fix spawn + ONE cross-review re-review round; still red → existing
escalation rules §8 apply), Medium/Low auto-defer as debt.

**Degraded mode (provider unavailable):** provider-opposite is the
PREFERRED reviewer, not a hard prerequisite. If the opposite provider's
CLI is missing or unauthenticated, the review falls back to
MODEL-opposite within the surviving provider: a DIFFERENT model than
the author's (recorded as `author_model` in `state.json`) — e.g.
Sonnet 5 reviewing Fable- or Opus-authored artifacts via
`claude -p --model`. The invariant that survives degradation is: the
gate is never satisfied by the same model that authored the artifact.
Every degraded review is logged and flagged in the morning report and
the PR body ("cross-review: model-opposite fallback") — never silent.

### P4 — Planning (= Skill 4, extended)

- Wave plans + `wave-gate-config.json` as today.
- NEW: execution-mode decision per wave (§6): Mode 1 paired lanes
  (default) / Mode 2 shared-checkout team inside the writer lane — only
  with listed proof that the stories' file sets are disjoint / Mode 3
  worktree writers (only if activated, Stage 4). Two independent CLI
  processes never write the same checkout together in any mode.
- NEW: pre-mortem review of the wave plans (unsafe ordering, weak AC
  commands, missing contracts) — the-fool modes PLUS the cross-model
  pass via `3a_cross-review`, which makes the old vague "have another
  model look it over" literal and structured.
- Then ◇ Checkpoint 1 — handled by the checkpoint skill (below).

### Checkpoint Skill `4a_checkpoint` (new)

Checkpoints are not a "looks good? yes/no" question but a structured
reconcile loop (generalizing the proven pattern from
`2c_review-reconcile`):

1. **Present:** a compact review package instead of raw artifacts —
   decision summary (delta), wave overview with rationales, open risks
   from the pre-mortem.
2. **Collect feedback in a structured way:** point by point
   (AskUserQuestion or guided conversation); every point ends with a
   decision: `adopt` / `change (how)` / `reject (why)` / `defer`.
3. **Write the decision log:** `specs/PROJ-<X>-<theme>/decisions.md` — every
   decision with rationale. The P7 curation reads it (decisions with
   lasting value migrate into ARCHITECTURE.md/ADRs).
4. **Cascade updates into artifacts:** one change ("drop US-7, cut
   Wave 2 differently") touches architecture-delta + wave plans +
   wave-gate-config + api-contracts. The skill propagates the change
   through ALL affected artifacts and then re-runs the plan self-review
   (the consistency check from Skill 4).
5. **Seal the approval:** create the minimal `state.json` if it does not
   yet exist — using the skill-shipped `state.sh` from
   `4a_checkpoint/scripts/` (the identical helper `4b_setup` later
   copies into the repo at P0) — then transition it to `approved` with
   a decision-log reference. Only this unlocks the phase runner for P0.

The same loop is used in three places:
- **CP1** (arch + plan): as above — the main application.
- **Bootstrap checkpoint** (§3): validation of the intake first drafts
  (PRODUCT/ARCHITECTURE/GUIDELINES) with the same point-by-point
  pattern.
- **CP2** (PR): `8_delivery` uses the same reconcile pattern for PR
  review comments (via `gh`): classify
  (`fix now` / `debt` / `reject with rationale`), fix spawns, ledger
  update, push, re-request review. Principle-level feedback
  ("I never want to see this again") is harvested as an AGENTS.md/
  GUIDELINES candidate.

### P0 — Setup (Skill `4b_setup`, new; replaces the FIRST-ACTION block from Skill 5)

Once per PROJ, fully automatic:

1. Create the `proj/PROJ-X` branch, tag BASE_SHA
2. **Check/update the context pack** (context-curator agent): the
   baseline from `docs/` is the foundation; PROJ-specific additions are
   architecture-delta, api-contracts, ground-file
3. **Generate the ground file** (common-ground principle): surface
   assumptions about stack/conventions/data model, validate them against
   the codebase
4. **Activate provider adapters:** Claude's SubagentStart hook and
   Codex's plugin/hook adapter inject the same type-scoped bundle. The
   shared bundle is canonical; provider wrappers may differ.
5. **Ponytail preflight on all ACTIVE providers:** plugin installed and
   mode `full` active? Coding-agent matcher scoped so reviewer and
   explore lanes do not receive it? Version/mode parity checked when
   both providers are active.
6. Preflights: check the CLI/tool list from §7 (including both provider
   auth states, not just `command -v`), plus `.coderabbit.yaml` and
   permissions.
7. Extend the CP1-created `state.json` with preflight results, provider
   lane IDs, artifact ownership, and the next legal phase.

### P5 — Execution (= Skill 5, loop per wave)

```
for each wave N:
  1. Start Claude + Codex lanes (execution mode per wave plan, §6)
     – Mode 1 paired: one writer on the PROJ branch, the other lane
       prepares tests/risks and reviews; roles may swap by story
     – Mode 2 parallel, file-disjoint → agent team in the writer lane's
       SHARED checkout; integration-guard observes; the peer lane
       stays read-only
     – Mode 3 parallel, overlap risk → own worktree + story branch each,
       then semantic merge gate
     – context arrives via hook; local knowledge via the agent.md
       reading protocol
  2. Per US: TDD + provider-opposite inner review loop
     – learnings IMMEDIATELY into the folder agent.md (deepest
       applicable level)
  3. Ralph loop per US (deterministic AC verification, cap 3)
  4. Mode 3 only: MERGE GATE — merge story branches into the PROJ
     branch in dependency order; auto-fix trivial conflicts; semantic
     conflicts = planning error → finding into the ledger + escalate
  5. WAVE GATE (script, extended):
     – AC commands + build (as today)
     – CodeRabbit `--agent --base-commit <wave-start>` (as today)
     – NEW: `sonar` local scan + secrets check (seconds, local)
     – smoke test (agent-browser) for frontend waves
     → all findings into the ledger; Critical/High block
  6. green → next wave without stopping
```

### P6 — Quality & QA (= Skill 5 steps 9/10 + Skill 6, reorganized around the ledger)

**Ownership boundary:** Skill 6 remains a strictly read-only finder. It
tests, reviews, and writes findings; it never changes production code or
dispatches fixes. The P6 phase controller owns the state machine,
ledger processing, fix dispatch, and re-verification. This preserves an
independent QA verdict without sacrificing unattended repair.

Three parallel read-only collection streams:
- Code review gate (code-reviewer-gate, as today)
- `sonar-scanner` full quality gate (once at PROJ end)
- QA: browser E2E + red team + UI audit + persona panel (Skill 6)

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
  the affected checks. The fixer never certifies its own repair.

After three failed repair/re-verification attempts on the same
Critical/High finding, P6 enters the stop behavior in §8. Exit requires
no Critical/High open. Medium/Low → **auto-defer**
(no user prompt, unlike today's Skill 5/6): debt marker in the code
(`ponytail:` convention with ceiling + upgrade path) + ledger status
`deferred`. The human decides about debt at Checkpoint 2 based on the
debt section in the PR — not mid-run.

### P7 — Docs & Curation (= Skill 7, moved BEFORE the PR)

1. Generate/update documentation (README, PROJECT.md, TECHNICAL.md)
2. **Curation step (the brownfield core):**
   - `docs/ARCHITECTURE.md` ← merge surviving decisions from
     architecture-delta; document deviations
     ("planned X, built Y, because …")
   - `docs/PRODUCT.md` ← new domain terms/scope changes
   - `docs/GUIDELINES.md` + merge candidates into project-root
     `AGENTS.md` through the existing approval pipeline
   - `docs/components.md` ← regenerate (`gen-component-registry.mjs`);
     curate the purpose lines in the components, never the table
   - **Curate folder agent.md files:** keep what is confirmed, delete
     what is outdated, promote what is project-wide
3. **Cross-model docs review (`3a_cross-review`, §4):** the provider
   opposite the curation writer reviews the curated delta against the
   PROJ diff; jointly curated artifacts receive independent Claude and
   Codex passes. Review focus: factual accuracy, stale claims,
   cap-gaming. Critical/High findings BLOCK P7 completion
   (fix + one re-review round); Medium/Low → debt per §8. The size
   caps (`curation-caps.sh`) check form; this step checks truth.
4. Commit everything to the PROJ branch → docs are part of the PR

### P8 — Delivery (new)

1. Rebase/conflict probe against `main` (throwaway worktree,
   `git merge --no-commit --no-ff`)
2. Classify conflicts: trivial (lockfiles, imports, formatting)
   → auto-fix; semantic → risk assessment into the PR + escalate
3. Create the PR (gh CLI) — body rendered by a **template script** from
   state.json + ledger (no LLM rendering): what was built, gate/QA
   results, known gaps (Ralph cap hits), debt ledger, 📚 doc changes
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
  diff. Both providers receive the same canonical bundle hash.
- `/compact` is demoted from load-bearing element to emergency fallback
  within a Claude lane; Codex compaction/resume is equally non-load-bearing.
- Side effect: crash resume and a normal phase transition are the same
  mechanism (start session, read state.json, continue).

### Four Layers, Each with Its Own Lifecycle

| Layer | Location | Lifetime | Distribution | Updated |
|---|---|---|---|---|
| 1. Durable agent policy | project-root `AGENTS.md` | forever | host-native instruction loading | only via approved P7 candidate merge |
| 2. Curated repo docs | `docs/` | forever | provider adapters / prompt bundles | only via P7 curation |
| 3. PROJ artifacts | `specs/PROJ-<X>-<theme>/` | until merge | prompt bundle / path reference | during the PROJ |
| 4. Local knowledge | `src/**/agent.md` | forever | reading protocol (explicit) | immediately on learning; curated in P7 |

### Files

```
AGENTS.md                      ← ROOT-ONLY durable agent rules

docs/                          ← LONG-LIVED, curated, injectable
├── PRODUCT.md                 ← "what am I even building" (½ page, hard cap)
├── ARCHITECTURE.md            ← overarching architecture (≤200 lines, hard cap)
├── architecture/…             ← details/ADRs, referenced only
├── GUIDELINES.md              ← code conventions, error handling, naming
├── DESIGN-SYSTEM.md           ← tokens, scales, patterns, do/don't (≤80 lines, hard cap)
└── components.md              ← component registry (GENERATED from the code)

specs/PROJ-<X>-<theme>/        ← PROJ artifacts
├── 0_context/                 ← existing-state inputs when applicable
├── 1_brainstorm/              ← approved concept
├── 2_visual-companion/        ← UI structure exploration when applicable
├── 3_PRDs/                    ← requirements snapshot
├── 4_design/                  ← optional design language
├── 5_mockups/                 ← mockups + implementation handoff when applicable
├── 6_plan/                    ← architecture + wave plans + gate config
├── 7_progress/                ← progress, stop reports, autonomous log
├── 8_handoff/                 ← generated discovery packages; immutable runs
├── architecture-delta.md      ← new decisions of this PROJ
├── api-contracts.md           ← interfaces between parallel stories
├── ground-file.md             ← validated assumptions
├── state.json                 ← state machine
└── findings.json              ← findings ledger

src/**/agent.md                ← local; NEVER injected
```

### Spawn Tiering (decides whether anything is injected at all)

The hook fires on EVERY SubagentStart — without tiering, the budget
multiplies with the spawn count (an overnight run = dozens of spawns,
most of them micro-fixes). Therefore the spawn class decides first, then
the agent type:

| Tier | Spawn class | Injection |
|---|---|---|
| 0 | Micro-fix (1 finding, 1 AC, 1 build error) | **NOTHING** — the spawn prompt contains the finding verbatim + file paths + possibly an agent.md pointer. It needs nothing more. |
| 1 | Story implementer (whole US) | full type-scoped pack (matrix below) |
| 2 | Reviewer/QA personas | PRODUCT.md + review criteria + diff scope; no ladder, no design system (except ui-audit) |
| — | Explore/scout spawns | nothing (read-only, own assignment) |

Implementation: **the tier is encoded in provider-neutral role
metadata** (`micro-fixer` = tier 0, `implementer`/`frontend-`/
`backend-implementer` = tier 1, `reviewer-*` = tier 2). Claude projects
that metadata into `.claude/agents/`; Codex projects it into its skill/
agent configuration. The compiled prompt bundle is the fallback and the
cross-provider source of truth, so hook feature differences cannot
change what context a role receives.

### Injection Matrix (Tier 1, type-scoped)

| Context | frontend impl. | backend impl. |
|---|:---:|:---:|
| PRODUCT.md | ✅ | ✅ |
| ARCHITECTURE.md (overview) | ✅ | ✅ |
| architecture-delta.md | ✅ | ✅ |
| GUIDELINES.md | ✅ | ✅ |
| Minimalism ladder | via the provider's Ponytail plugin adapter (§7); same mode/version on Claude and Codex ||
| DESIGN-SYSTEM.md + components.md | ✅ | — |
| api-contracts.md (ONLY contracts of the own US/wave) | as needed | ✅ |
| Security baseline | — | ✅ |
| Test conventions | ✅ | ✅ |
| ground-file.md | ✅ | ✅ |
| US + ACs + tasks | via spawn prompt (orchestrator, as today) ||
| "what earlier waves built" | one-liner per US, generated from state.json ||
| Folder agent.md | reading protocol (below), never injected ||
| PRDs, full wave plans, architecture/* | path reference, on demand ||

**Redundancy rules (overlap costs double):**
- `ground-file.md` contains ONLY assumptions that are not yet in
  `docs/` — whatever is validated and has lasting value migrates into
  ARCHITECTURE/GUIDELINES via curation and is removed from the ground
  file.
- `architecture-delta.md` references the baseline, never repeats it.
- `api-contracts` are scoped per wave/US, not injected as a whole-PROJ
  file.

**Budget enforcement (instead of budget intent):**
- The context-curator compiles a bundle per agent type and COUNTS
  tokens. The P0 preflight fails if a bundle exceeds the budget
  (~2–3k tokens) → condense first, then start.
- File caps (PRODUCT ½ page, ARCHITECTURE 200 lines, DESIGN-SYSTEM
  80 lines, agent.md 100 lines, …) are checked as a hard gate in the P7 curation —
  otherwise the curated docs grow unnoticed until every session gets
  more expensive.

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
  every entry with date + commit SHA. Max ~100 lines per file — beyond
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
  disjoint (it must list them). The stories then run as an agent team
  INSIDE the writer lane's process, in the shared checkout, with the
  integration-guard as observer — exactly today's Skill 5 model. The
  peer lane stays read-only for the whole wave. No branches, no merge
  gate, near-zero extra machinery; the single-writer-process invariant
  is untouched.
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
- **Order per parallel wave:** per-US Ralph runs IN the worktree
  (cwd = worktree; the code is not merged yet) → merge gate →
  wave gate (build, CodeRabbit, Sonar, smoke) ONCE on the merged PROJ
  branch.
- The integration-guard (observer in Mode 2) becomes the semantic
  **merge gate** in Mode 3: merge in dependency order, fix trivial
  conflicts, escalate semantic ones. Additionally: **union merge of
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
| Type-scoped context | SubagentStart hook / prompt file | Codex plugin hook / prompt file | same compiled bundle hash |
| Agent role | `.claude/agents/*.md` | Codex skill/agent metadata | role, tools, write scope, budget |
| Minimalism | Ponytail Claude plugin | Ponytail Codex plugin | same Ponytail mode and rule version |
| Cross-review | OpenAI `codex-plugin-cc` pattern | Codex-facing `claude` skill pattern | provider opposite to `author_provider` |
| Wave-gate enforcement | PreToolUse hook (`wave-gate-enforcer.js`) as defense-in-depth | prompt contract (no verified hook equivalent) | RUNNER-owned: the next wave/lane is not started until `wave-gate.sh` exits 0; hooks only harden this, they don't carry it |
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

**Mode 2 verification (at latest before the first Mode 2 wave):** does
SubagentStart also fire for team teammates? (proven only for Task
spawns). Fallback: put the bundle into the teammate prompt.

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
| `node` | hooks (context injector, ponytail, wave-gate-enforcer) + scripts (ledger, rendering) | ✅ hard |
| `jq` | wave-gate.sh, ledger scripts, state.json helpers | ✅ hard |
| `coderabbit` | wave review (`--agent --base-commit`) | ✅ hard (gate component) |
| `codex` | Codex phase lane + provider-opposite review via `codex exec` | 🟡 preferred, degradable — missing/unauthenticated → single-provider run with model-opposite review, flagged in report + PR body, never silent |
| `agent-browser` | smoke tests in the wave gate, browser E2E in P6 | ✅ hard for frontend waves; backend-only: unused |
| `sonar` | local scan + secrets check in the wave gate | 🟡 skippable with log entry |
| `sonar-scanner` | full quality gate at PROJ end (P6) | 🟡 skippable with log entry |
| `supabase` | migrations, types, local instances (if the product uses Supabase) | 🟡 only if Supabase in the stack |
| Jira access (Atlassian MCP or CLI/REST) | PRD intake Mode B (P2d) + status sync-back | 🟡 TODO — only for Mode B (Stage 3); Mode A (local PRDs in specs/) needs nothing |
| `npm`/`pnpm` | build/tests; pnpm decision for worktree installs is made in Stage 4 | ✅ hard (project-dependent) |
| Ponytail plugin | minimalism ladder through aligned Claude and Codex adapters (needs `node`) | ✅ hard on all ACTIVE providers (§7 below) |

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

### Sonar — Two Stages (two CLIs, two jobs)
- **`sonar`** (developer CLI): local change analysis + secrets scan in
  the WAVE GATE — fast, local, no CI round trip. Secrets are found
  BEFORE they enter the branch history, not at PROJ end.
- **`sonar-scanner`**: full project analysis + quality gate ONCE at
  PROJ end (P6). Setup/auth/coverage per the `sonar-cli` skill.
- **Environment: SonarQube Cloud, already set up** (org, token, project
  config present) — the P0 preflight only verifies auth
  (`sonar auth status`, `SONAR_TOKEN`) instead of doing setup.
- If the CLIs are missing on the machine: skip with a log entry, never
  block.

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
  peer lane and all cross-reviews fall back to a different Claude model
  than the author's (e.g. Sonnet 5), recorded in `state.json` and
  flagged in the morning report and PR body.

### ponytail (ready-made plugin — DECIDED, do not rebuild ourselves)

The minimalism ladder is NOT maintained as our own bundle component;
Ponytail now ships native Claude Code and Codex plugin adapters backed
by a shared runtime, so both lanes use the same rule version and mode:

```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail

# Codex
codex plugin marketplace add DietrichGebert/ponytail
# install from Codex /plugins, then review/trust its hooks
```

- **Mode:** persist `full` as the default on all active providers and
  record the detected plugin version/mode in P0 state.
- **Scoping:** apply Ponytail only to code-writing roles
  (`implementer|frontend-implementer|backend-implementer|micro-fixer`);
  reviewer, QA, and explore lanes do not get the ladder.
- **No double injection:** our context injector carries NO ladder of
  its own — ponytail is the single source for it.
- **Debt integration:** ponytail's `ponytail:` comment convention is
  our debt-marker convention (P6). Harvest for PR body/morning report
  via `/ponytail-debt` or our own grep script into the ledger.
- **Parity gate:** when BOTH providers are active, Claude and Codex must
  report the same Ponytail rule version and mode; a mismatch blocks P0
  until versions are aligned. In degraded single-provider mode the gate
  applies to the surviving provider alone.
- **Update policy:** check plugin updates occasionally; pin one version
  across both providers when hook behavior changes.

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
template inside the skill's `templates/` directory. `4b_setup` copies
both into the repo (`scripts/`, `templates/`) and commits them —
versioned with the repo, testable outside sessions, identical behavior
on every machine. Skill 5's `scripts/wave-gate.sh` is the existing
proof of the pattern.

**Schemas:** `state.schema.json` and `findings.schema.json` ship with
the framework. `state.sh` and `ledger.mjs` validate on every write —
an agent writing a malformed record fails loudly at write time, not
silently at render time.

#### Script specifications

| Script (skill) | Input | Output | Behavior / exit |
|---|---|---|---|
| `preflight.sh` (4b_setup) | CLI list §7 (embedded), env | report to stdout; state.json `preflight` block | checks `command -v` + auth per tool; exit ≠ 0 on any missing HARD tool (stop condition); skippable tools → logged skip |
| `compile-context-bundles.mjs` (4b_setup) | root `AGENTS.md`, `docs/*`, `specs/PROJ-<X>-<theme>/*`, injection matrix §5 | one canonical bundle per role plus Claude/Codex projections | counts tokens and hashes both provider projections; exit ≠ 0 on budget breach or semantic drift |
| `state.sh` (4b_setup) | `get <path>` / `set <path> <value>` / `transition <phase> <status>` | state.json (validated) | sole write path to state.json; schema-validates; illegal phase transitions exit ≠ 0 |
| `wave-gate.sh` (5_executing, exists) | wave N, PROJ, config | gate verdict; PASSED block in progress.md; findings → ledger | extended: `sonar` local scan + secrets check, component-registry `--check`; any Critical/High → exit ≠ 0 |
| `gen-component-registry.mjs` (5_executing) | `src/components/**`, `src/features/*/components/**` | `docs/components.md` | reads the doc block above each component export; `--check` exits ≠ 0 on a stale registry or a component without a doc block (wave-gate step 6). The registry is never hand-written — one source, the component file |
| `ledger.mjs` (quality) | raw findings (JSON lines from all sources) | deduped, normalized `findings.json`; fix-queue clusters | dedupe key file/line/category; severity mapping table embedded; idempotent (re-run safe) |
| `cross-review.sh` (3a_cross-review) | mode, artifact files, `author_provider` + `author_model`, prompt template | provider-attributed findings JSON lines → `ledger.mjs` | routes to opposite provider; fallback: model-opposite via `claude -p --model` (logged + flagged); joint artifacts launch both adapters concurrently; max 2 rounds |
| `review-with-claude.sh` (3a_cross-review) | rendered prompt + limits | normalized Claude JSON lines | invokes `claude -p` read-only; validates output; timeout/cancel as one process group |
| `review-with-codex.sh` (3a_cross-review) | rendered prompt + limits | normalized Codex JSON lines | invokes `codex exec` read-only; validates output; timeout/cancel as one process group |
| `harvest-debt.sh` (quality) | repo tree | `ponytail:` markers as ledger records (status `deferred`) | grep-based; links marker → file/line; idempotent |
| `curation-caps.sh` (7_documentation) | `docs/*`, `src/**/agent.md` | cap report | exit ≠ 0 on any cap breach (PRODUCT ½ page, ARCHITECTURE 200 lines, DESIGN-SYSTEM 80 lines, agent.md 100 lines) — curation must shrink before P7 completes |
| `conflict-probe.sh` (8_delivery) | PROJ branch, `main` | conflict report (JSON: none/trivial/semantic per file) | throwaway worktree, `merge --no-commit`; never touches real branches; classification by file type heuristics |
| `render-pr-body.mjs` (8_delivery) | state.json + findings.json + template | PR body markdown | pure render, no side effects |
| `ci-poll.sh` (8_delivery) | PR number | check status JSON; failed-check logs verbatim | wraps `gh pr checks --watch`; timeout from config; exit ≠ 0 after timeout |
| `run-phase.sh` (framework root) | phase id, PROJ | launches Claude + Codex lane processes concurrently | validates legal transition, assigns writer/reviewer roles, captures provider outputs, waits/cancels as a unit, records lane start/end in state.json |
| `render-report.mjs` (framework root) | state.json + findings.json of all PROJs in the run + template | `specs/morning-report-<date>.md` | pure render; also emits the one-liner for the push notification |

#### Template inventory

| Template (skill) | Data source | Rendered artifact | When |
|---|---|---|---|
| `pr-body.md.tmpl` (8_delivery) | state.json + findings.json | PR description: built scope, gate/QA results, known gaps, debt section, 📚 doc changes | P8 step 3 |
| `morning-report.md.tmpl` (framework) | state.json + findings.json (all PROJs) | `specs/morning-report-<date>.md` | run end |
| `stop-report.md.tmpl` (framework) | state.json + verbatim error capture | `specs/PROJ-<X>-<theme>/7_progress/stop-report.md` | on stop condition |
| `decisions.md.tmpl` (4a_checkpoint) | reconcile-loop results | `specs/PROJ-<X>-<theme>/decisions.md` (append per checkpoint) | CP1/bootstrap/CP2 |
| `progress-blocks.md.tmpl` (5_executing) | state.json | the structured blocks in progress.md (wave gate PASSED, Ralph iterations, QA results) | after each gate/loop |
| `jira-comment.md.tmpl` (2d_prd-import, Mode B) | state.json + findings.json | status/PR-link/debt comments on tickets | sync-back (TODO) |
| `agent-md-entry.md.tmpl` (5_executing) | learning (free text) + date + commit SHA | uniform agent.md entry block | on write — the one place where LLM content flows in, but inside a fixed frame |
| `cross-review-prompt.md.tmpl` (3a_cross-review) | mode + artifact list + author provider | provider-neutral adversarial prompt rendered for either CLI | P3, P4, P7 |

Free-form LLM text still exists — analysis, findings verification,
architecture prose, agent.md learnings — but it always lands INSIDE a
template frame or a schema field, never as an unstructured document of
its own. The `state.sh` helpers matter most: one tested write path
instead of dozens of ad-hoc jq calls. Agent definitions themselves stay
declarative (frontmatter: model, tools); their lifecycle scripting
lives in hooks, which are scripts anyway (context injector, ponytail,
wave-gate-enforcer).

### Findings Ledger (`findings.json`)
One record per finding: source (coderabbit/sonar/review/qa/merge-gate),
file/line, category, normalized severity, status
(open/fixed/deferred/false-positive), fix commit, debt-marker reference.
The PR body and progress.md are generated FROM this, not maintained by
hand.

---

## 8. Autonomy Policy (Overnight Runs)

After Checkpoint 1 the process runs without user interaction up to the
finished PR — including across several PROJs in sequence (Checkpoint 1
can approve several PROJ plans at once; they then run through
sequentially).

### Escalation Rules (replace all "ask the user" spots)

| Situation | Behavior |
|---|---|
| Medium/Low findings & bugs | auto-defer: debt marker + ledger, decision at Checkpoint 2 |
| Ralph cap hit (3 iterations) | log as known gap, continue (as today) |
| Wave gate red | fix and re-run; 3× red on the SAME check → stop condition |
| Critical bug survives 3 fix attempts | stop condition |
| Semantic merge conflict (parallel) | 1 resolution attempt with the contract as reference; unresolved → stop condition |
| Tool missing / auth broken / env broken | stop condition (never skip silently — except explicitly marked skippable, e.g. Sonar) |
| Rate limit exhausted (CodeRabbit) | wait until the window frees up, max 1h; then stop condition |
| Security-critical (secrets in code, auth bypass) not auto-fixable | stop condition, do NOT commit the wave |

### Stop Behavior ("bad problems")

On a stop condition the run is NOT simply aborted but parked in a
controlled way:

1. **Secure:** commit all uncommitted changes to a
   `rescue/PROJ-X-<timestamp>` branch; document open worktrees and dev
   servers (do not delete — evidence)
2. **`state.json` → `blocked`** with the exact stop cause
3. **Write the stop report** (`specs/PROJ-<X>-<theme>/7_progress/stop-report.md`):
   - What happened (verbatim error output, last 3 attempts)
   - State: which waves are done, what is half-finished, which
     branches/worktrees are open
   - **Cleanup list:** what the human/the next run must clean up
   - Recommended next action
4. If more PROJs are queued and the failure is PROJ-local: start the
   next PROJ. On environment failures (env/tools): end the whole run.

### Morning Report

At the end of every run (successful or stopped), a report is rendered
from `state.json` + `findings.json` by a **template script**
(`specs/morning-report-<date>.md`): per PROJ status, PR link, gate/QA
summary, deferred debt, known gaps, provider/model degradations
(cross-review fallbacks), stop reports, cleanup list. It is
the first thing the human reads in the morning — before the PRs.

**Delivery:** the report file is canonical. At run end the runner sends
a best-effort provider/OS notification with a one-liner status
("2 PROJs done, 2 PRs open, 1 stop report") and the path to the report;
notification failure never loses or invalidates the report.

---

## 9. Differences from Today's Chain

| Change | Replaces/extends |
|---|---|
| P3 reads/writes the curated ARCHITECTURE.md, produces a delta | Skill 3 (per-PROJ architecture without a baseline) |
| P0 setup with context pack + injector hook | FIRST-ACTION block + if/else context logic in Skill 5 |
| Paired Claude + Codex lanes by default; worktrees for concurrent writers | one host process plus same-host subagents in a shared checkout |
| `sonar` local scan + secrets in the wave gate | Sonar only at PROJ end |
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
| Provider-opposite Claude ↔ Codex review of pre-mortems + curated docs | same-model persona review only; docs content never reviewed |

Unchanged and explicitly preserved: the current pre-PRD Skills 1–2
flow, both delivery tracks, immutable generated `8_handoff/` packages,
the Ralph loop mechanics, the TDD cycle, the wave-gate script principle,
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
   `4b_setup` with the context compiler and provider projections,
   context-injector adapters (define the
   manifest schema following the claude-skills frontmatter taxonomy),
   install + parity-check Ponytail on Claude and Codex (§7), agent.md protocol +
   P7 curation, `3a_cross-review` skill (mechanism + the P7 docs call
   site — it ships with the curation it guards)
3. **Stage 3:** P3 rework (baseline/delta), pre-mortem reviews in
   P3/P4 (including wiring the Stage 2 `3a_cross-review` into both).
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
| Skill numbering | dock on: `0b_intake`, `2d_prd-import`, `3a_cross-review`, `4a_checkpoint`, `4b_setup`, `8_delivery` |
| PRD source | TWO modes, downstream identical. Mode A (DEFAULT): PRDs written directly into the repo (existing structure) — the new chain is tested in this mode first. Mode B (TODO, Stage 3): Jira import, created/enriched via Teklens (teklens.ai); local snapshot = working truth per run; Jira keys in commits/PRs; sync-back |
| PRD ownership | PM PRDs are raw input: developers enrich with technical stories, re-cut into buildable PRDs (in Jira for Mode B), and OWN the selection of the story set sent into the agentic loop — the framework checks AC quality, not scope |
| Morning report | file in `specs/` (canonical) + best-effort notification at run end |
| Minimalism ladder | Ponytail as a ready-made plugin on all active providers; same version/mode required when both are active, no own ladder, no double injection |
| Context pack manifest | schema following the claude-skills frontmatter taxonomy, defined when building the injector (Stage 2) |
| Cross-model review | symmetric provider-opposite review via our thin `3a_cross-review`: Claude-authored → Codex, Codex-authored → Claude, joint → both independently; fallback when a provider is unavailable: MODEL-opposite within the surviving provider (e.g. Sonnet 5 reviews Fable-authored artifacts), flagged — same-model review never satisfies the gate; findings → ledger, blocking per §8 |
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
   at the merge gate instead of corrupting a shared dev DB.

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
