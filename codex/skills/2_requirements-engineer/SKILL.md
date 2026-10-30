---
name: requirements-engineer
description: "Create detailed feature PRDs with user stories, acceptance criteria, and edge cases after Visual Companion, optional Frontend Design, and Prototyping. Use when: (1) an approved concept and optional UI mockups need to become structured PRDs, (2) user stories and acceptance criteria must be written, (3) edge cases must be identified. Not for: UI mockups, writing code, technical design, or debugging."
---

# Requirements Engineer

## External product ownership

This skill authors product-owned sources. An incoming external package routes to `handoff-refinement`; do not copy it into `2_PRDs/` and revise it as a new canonical contract. Developer technical constraints belong in the receiving refinement, not product PRDs. Product-approved changes return through `review-reconcile` in the source project and, when needed, a new `handoff-package` run. Local authoring below is unchanged.

## Artifact Language

From Requirements Engineer (Step 2) onward, write all newly authored artifacts
in English: PRDs, plans, decision records, handoff packages/prompts, findings,
worker reports, QA evidence summaries, documentation and PR descriptions.
Converse with the user in their language. Preserve identifiers, file paths,
verbatim source evidence and the product's required UI/localization language.
Concepts and discovery inputs may use another language; derive English artifacts
from them. Before CP1 approval, return non-English canonical PRD ACs to
Requirements Engineer for an approved English revision before downstream
verbatim copying. On resume after CP1 is sealed, preserve approved PRD/plan ACs
verbatim; a newer language policy alone must not reopen approval. New records
remain English. Change sealed canonical ACs only through an explicit user-
authorized revision and the owning review; never silently translate them.


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


Turn the approved concept into structured Product Requirements Documents. Focus on what the feature must do, not how it will be implemented.

Never write code or technical architecture in this skill. Architecture and implementation happen later in the chain.

## PROJ vs. PRD

- **PROJ-X** is the initiative or feature theme, for example `PROJ-1-auth`. Concept assigns it and creates the folder.
- **PRD-Y** is one testable, deployable feature inside the PROJ. Number PRDs from 1 within each PROJ.

## Feature Granularity

Each PRD should describe one testable, deployable unit.

Split into a separate PRD when:

1. It can be tested independently.
2. It can be deployed independently.
3. It serves a different user role.
4. It is a separate UI component, screen, API capability, or workflow.

Prefer several focused files inside the same PROJ over one large PRD:

```text
specs/PROJ-1-auth/2_PRDs/
  PROJ-1-PRD-1-user-signup.md
  PROJ-1-PRD-2-login.md
  PROJ-1-PRD-3-password-reset.md
```

Document dependencies between PRDs, including cross-PROJ dependencies, inside each PRD.

## Delivery Track

Detect how this PROJ will be delivered before writing PRDs. The concept's `Handoff Readiness` section (written by `concept`, confirmed by `concept-sync`) sets `Delivery track`. A legacy concept without it: ask the user once and write the answer into the concept.

- **Full chain (in-repo build):** Steps 3–7 follow in this repo. Write PRDs normally, including the short `UI Implementation Notes` section (screen references and a pointer to the handoff).
- **Discovery / Linear handoff:** There is no codebase here. You are producing a developer handoff that goes to Linear (https://linear.app). The developer who picks it up owns architecture and implementation. In this mode:
  - Write the same PRDs (user stories, acceptance criteria, edge cases) — these are the contract.
  - Do **not** invent in-repo file paths or component locations. `UI Implementation Notes` carries mockup references only.
  - Do **not** recommend `architecture` (3); the chain stops at Step 2 for this PROJ.

## Decomposed PROJ Handling

Requirements run one PROJ at a time. If the concept contains `Decomposition Context`:

- Write PRDs only for the current PROJ.
- Do not absorb sibling PROJ scope into user stories.
- Document cross-PROJ dependencies explicitly under `## Dependencies`.
- If a sibling PROJ is a blocker, do not write stories that assume its behavior except as a dependency or precondition.
- A shared design language from a sibling PROJ may be referenced, but it does not expand the current product scope.

## Input

Read these inputs:

1. `docs/PRODUCT.md` (30 lines) — purpose and audience
2. Concept: `specs/PROJ-<X>-<theme>/1_concept/PROJ-<X>-concept.md` — all sections except `Direction Log`, `Assumptions Confirmed`, `Risks And Trade-Offs`, `Testing Focus`
3. UI mockups: follow the screen/source references in `1d_prototypes/implementation-handoff.md`; for legacy HTML handoffs without that section, read the screen HTML files in `1d_prototypes/`.
4. UI implementation handoff: `specs/PROJ-<X>-<theme>/1d_prototypes/implementation-handoff.md`
5. Optional Visual Companion decision: `specs/PROJ-<X>-<theme>/1b_visual-companion/layout-decision.md`
6. Optional design language: `specs/PROJ-<X>-<theme>/1c_design/design-language.md`
7. Optional shared sibling design language referenced by the concept, layout decision, or mockup handoff

Do not read `1_concept/PROJ-<X>-direction-log.md` or anything under `_dropped/`: they hold discarded directions, not requirements input.

For UI features, mockups and `implementation-handoff.md` are required inputs. They define screens, flows, states, component reuse, new component candidates, design tokens, the interaction contract, and implementation tolerance.

If a UI feature has no mockups, stop and run `visual-companion` -> optional `frontend-design` -> `prototyping` first. Pure backend/API features may proceed directly from the concept. If the concept still lists `Candidate Directions`, or `1d_prototypes/iteration-log.md` has an `Affects concept: yes` entry the concept's `Concept Sync Log` does not cover, stop and run `concept-sync` first.

## Workflow

### 1. Check Existing PRDs

Before creating a PRD, inspect `specs/PROJ-<X>-<theme>/2_PRDs/`.

Use the next available `PRD-Y` number inside the PROJ, starting at 1 and avoiding gaps where practical. Do not duplicate existing PRDs.

### 2. Understand The Feature

For UI features, resolve screens through the implementation handoff (its `Screen References` and `Flow Descriptions` carry the sitemap facts), then read the mockups:

- Which screens exist?
- Which user flows are clickable or linked?
- Which states are visible?
- Which assumptions or source references are marked?
- Which `Project Mode` applies?
- Which components and tokens must be reused?
- Which new component candidates did the user accept?
- Which interactions are implementation contract vs. demo-only?

Ask the user focused questions only when needed:

- Who are the primary users? (answer from `docs/PRODUCT.md` and the concept; ask only if both are silent)
- What is MVP scope vs. nice-to-have?
- What constraints exist?

Ask one question at a time and follow up based on the answer.

### 3. Clarify Edge Cases

Identify and prioritize edge cases:

- Unexpected inputs
- Empty or missing data
- Permission and role boundaries
- Failure and retry behavior
- Security-relevant scenarios
- Limits, quotas, and performance-sensitive paths

### 4. Write PRDs

Save PRDs under:

```text
specs/PROJ-<X>-<theme>/2_PRDs/PROJ-<X>-PRD-<Y>-<short-description>.md
```

Use kebab-case for `<short-description>`.

Template:

```markdown
# PROJ-<X>-PRD-<Y>: Feature Name

## Status: Planned

## User Stories

### US-1: As a [user type], I want [action] so that [goal]
**Given** [starting condition]
**When** [action]
**Then** [expected result]
**And** [additional expected result, if needed]

**Acceptance Criteria:**
- [ ] AC-1: Testable criterion derived from the Then/And clauses
- [ ] AC-2: Another testable criterion for this story

### US-2: As a [user type], I want ...
**Given** ...
**When** ...
**Then** ...

**Acceptance Criteria:**
- [ ] AC-3: ...

## Edge Cases
- What happens when...?

## Dependencies
- Requires: PROJ-<X>-PRD-<Y>
- Cross-PROJ dependency: PROJ-<A>-PRD-<B>

## Technical Requirements
- Performance, security, compatibility, or operational constraints.

## UI Implementation Notes
- Screen reference(s): <screen/source from `implementation-handoff.md`>
- Reuse, candidates and tokens: `1d_prototypes/implementation-handoff.md` § Reuse, New Component Candidates, Design Tokens And Styling, Interaction Contract
```

Each user story owns its own acceptance criteria. Do not create one global acceptance-criteria section. Derive ACs directly from the story's Given/When/Then/And clauses and make them testable.

### 5. Automatic Cross-Review, Then User Review
In a PROJ, save review findings to `2_PRDs/findings.json` through
`chain findings`; status updates stay in that file. For a free-standing review
outside a PROJ structure, report findings without saving a file.

Before presenting the PRDs to the user or starting provider review, run:

```bash
bash ~/.codex/skills/5_executing/scripts/chain check prds specs/PROJ-<X>-<theme>/2_PRDs
```

Re-run after every PRD change, including review reconciliation. A non-zero exit
blocks review and handoff; fix structure in this skill. The gate checks the
complete PRD set without architecture, waves or runtime state. It checks format,
not completeness or quality of the requirements.

Immediately after saving the complete PRD set and passing the structure gate,
start the required opposite-provider cross-review in the same turn, before
presenting the PRDs for user review or handoff. Do not ask whether to start it,
wait for user approval, or end the turn with an offer to run it later. Do not ask
the user to copy PRDs into another model manually. Review the complete PRD set;
omitting one PRD makes dependency and consistency findings unreliable.

Build the ground-truth list from files that exist. Always include the concept.
For UI work, add the compact UI contracts (`implementation-handoff.md`,
layout decision, and design language) rather than every mockup
source file unless a disputed detail requires it:

```bash
BASE="specs/PROJ-<X>-<theme>"
GROUND_TRUTH=("$BASE/1_concept/PROJ-<X>-concept.md")
for candidate in \
  "$BASE/1d_prototypes/implementation-handoff.md" \
  "$BASE/1b_visual-companion/layout-decision.md" \
  "$BASE/1c_design/design-language.md"; do
  [ ! -f "$candidate" ] || GROUND_TRUTH+=("$candidate")
done
bash scripts/chain review requirements <X> <theme> \
  --artifacts "$BASE"/2_PRDs/PROJ-<X>-PRD-*.md \
  --ground-truth "${GROUND_TRUTH[@]}" \
  --author-provider <current-writer> --round 1
```

The review must test concept/UI traceability, missing or contradictory stories,
acceptance-criteria testability, edge and permission behavior, cross-PRD
consistency, scope drift, and premature architecture.

Follow `cross-review`'s automatic loop: reconcile findings of any severity
within approved scope and run `--round 2`, then `--round 3` while findings
remain. Stop early with no findings; exit `0` may still contain Medium/Low.
Ask the user only for unresolved product decisions. After round 3, remaining
Critical/High findings block handoff; report or defer remaining Medium/Low.
Exit `1` means the review did not run: fix infrastructure before handoff.

Three rounds is the automatic maximum; additional manually requested rounds
have no limit. The review is read-only and does not replace final
product-owner approval.

After the automatic review loop, present the PRDs and review result to the user
for approval. If the user requests changes, update the PRDs, repeat the structure
gate and automatically run cross-review on the revised set before presenting it
again. Final user approval remains required before handoff.

### 6. Handoff

- **Full chain:** recommend `architecture` (3) for PROJ-level technical design. For UI features, the mockups and implementation handoff remain visual references for architecture. If an external review package is requested, `handoff-package` (2b) can export the approved artifacts without changing the delivery track or replacing architecture.
- **Discovery / Linear handoff:** do not recommend `architecture`. If the work goes to people outside this repo (an external UI/UX expert, an external dev team) and a single standalone deliverable is wanted, recommend `handoff-package` (2b) to assemble a self-contained, zippable package. The chain ends here for this PROJ.

## Completion Checklist

- [ ] Existing PRDs checked for duplicates and next PRD number
- [ ] Necessary user questions answered
- [ ] UI mockups read for UI features
- [ ] `implementation-handoff.md` read for UI features
- [ ] At least 3-5 user stories defined where feature size warrants it
- [ ] Every user story has its own acceptance criteria
- [ ] At least 3-5 edge cases documented where feature size warrants it
- [ ] PRD ID assigned and file saved in the correct folder
- [ ] Delivery track determined (full chain vs. discovery / Linear handoff)
- [ ] Required opposite-provider PRD cross-review completed
- [ ] No unresolved Critical/High cross-review finding remains
- [ ] User reviewed and approved the PRD

## Git Commit Format

```text
feat(PROJ-<X>-PRD-<Y>): Add PRD for <feature-name>
```

Git is optional on the discovery track. If the workspace is not a git repository, skip the commit; the PRD files are the durable artifacts.

Legacy PROJ folders: see `0_chain-guide/references/legacy-layout.md`.
