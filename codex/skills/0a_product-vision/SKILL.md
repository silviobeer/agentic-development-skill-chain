---
name: product-vision
description: "Establish what a product IS before any feature is designed: interview the product owner into docs/PRODUCT.md (purpose, audience, non-goals, success) and cut the product into a numbered PROJ map in specs/product-roadmap.md. Use when: (1) a new product/project starts and no docs/PRODUCT.md exists, (2) the product direction changed and the map needs a revision round. Not for: a single feature in an existing product (use brainstorming), extracting the baseline from an existing codebase (use intake), stack or scaffold decisions, feature detail."
---

# Product Vision — What Are We Building, And In What Order

The chain's highest zoom level. `brainstorming` (1) turns ONE idea into ONE
buildable PROJ concept; it has no artifact above the PROJ. So on a new
product the question "what is this thing, and what is it deliberately not"
gets discussed once, decomposed into PROJs, and then evaporates — and every
agent downstream works without product context.

This skill fills that slot. It is the greenfield counterpart of `intake`
(0b): same curated baseline, reached by decision instead of by extraction.

| Path | Skill | Method |
|---|---|---|
| New product, no code | **this skill** | interview → decide |
| Existing codebase | `0b_intake` | scan → provenance-marked drafts → interview |

## Codex Adaptation

This skill is aligned with the Claude variant. In Codex:

- No AskUserQuestion tool: ask the six interview topics as single questions
  in the conversation and wait for each answer before the next one.
- Reusable skill assets live under `~/.codex/skills/...` instead of
  `~/.claude/skills/...`.
- Everything else — the two artifacts, the cap, the map rules, the
  revision round — is identical.

Both fill `docs/PRODUCT.md`. Neither overwrites the other: if the file
exists, this is a **revision round** — every existing statement stays unless
this session explicitly retires it, and the retirement lands in the roadmap
changelog.

<HARD-GATE>
No technology here. Not the framework, not the database, not the hosting.
The stack is decided when the project is set up; deciding it during a
product interview means deciding it without the architecture.
</HARD-GATE>

<HARD-GATE>
No feature detail. One sentence of user outcome per PROJ, no user stories,
no screens, no acceptance criteria. Those belong to `brainstorming` (1) and
`requirements-engineer` (2), and a second list of them here would be a
second source of truth that is wrong within a month.
</HARD-GATE>

<HARD-GATE>
Do not fill gaps with assumptions, and do not accept "yes"/"sounds
right"/"probably" as an answer to a concrete question. Re-ask with
alternatives.
</HARD-GATE>

## Input

- The user's product idea, in whatever shape it arrives.
- Anything already written: a pitch, notes, a competitor list, a spreadsheet.
  Read it before asking — never ask what a provided document already says.

No repo is required. This skill runs before the project exists.

## Workflow

### 1. Interview — ask one question at a time

Six topics, in this order. Each answer is one or two sentences, not a
document. Stop as soon as a topic is genuinely settled; do not perform
thoroughness.

1. **What is it?** One sentence a stranger understands. Not the feature
   list — the thing.
2. **Who uses it, concretely?** Roles, not demographics. If there are two
   very different users, name both — that difference usually shows up again
   as a PROJ boundary.
3. **What problem, and how is it solved today?** The status quo is the real
   competitor. "In a spreadsheet" is a valid and very informative answer.
4. **What is it deliberately NOT?** The hardest and most valuable question.
   Push for at least two concrete non-goals. Vague scope at this level
   becomes an unbounded backlog three skills later.
5. **When is it a success?** An observable outcome, not a metric dashboard.
6. **What is fixed?** Hard constraints only — a deadline, a regulatory
   requirement, a platform that must be supported, a customer already
   promised something. Preferences are not constraints.

Where the answer is genuinely open, offer two or three concrete
alternatives with a recommendation. Never leave the topic on "we'll see".

### 2. Cut the product into PROJs

Propose the map, do not impose it. A PROJ is a slice that delivers one user
outcome and can be shipped and validated on its own.

Cut when two or more hold: different user outcome · different audience ·
independent risk · independently shippable · different downstream path
(UI-heavy vs. backend-only). Do **not** cut merely because something is
large — pieces that only create value together stay one PROJ.

Present the map with dependencies and a recommended first PROJ, with the
reason. Use temporary labels (`PROJ-A candidate`) until the user approves
the cut. **Real numbers are allocated only after approval** — the roadmap is
the record of that approval, which is why the numbers are handed out here
and not in `brainstorming`.

### 3. Write the two artifacts

**`docs/PRODUCT.md`** — the curated baseline slot. Injected into every
context bundle, therefore **capped at 30 non-blank lines**
(`curation-caps.sh`). It answers what/who/not, nothing else:

```markdown
# <Product>

<One sentence: what this is.>

## Users
- <role> — <what they come here to do>
- <role> — <…>

## Problem
<How it is solved today, and why that is not good enough.>

## Non-Goals
- <what this product deliberately does not do>
- <…>

## Success
<The observable outcome that means this worked.>

## Constraints
- <hard constraint, or "none">
```

**`specs/product-roadmap.md`** — the map. Lives in `specs/`, is **not**
injected into context bundles, therefore costs no token budget and may grow:

```markdown
# Product Roadmap — <Product>

Source: `docs/PRODUCT.md` · Numbers allocated here · Status updated by `1_brainstorming`

## Map
| # | Theme | User outcome (one sentence) | Depends on | Status |
|---|---|---|---|---|
| PROJ-1 | auth | A user signs in and stays signed in across devices | — | planned |
| PROJ-2 | inventory | An owner sees current stock without a spreadsheet | PROJ-1 | planned |

## Boundaries
Only the edges where scope would otherwise bleed between siblings.
- PROJ-1 owns sessions and password reset. Roles/permissions are PROJ-4.
- PROJ-2 owns stock levels. Purchase orders are PROJ-5.

## Not Now
Deliberately deferred, one line of reasoning each — the product-level
"out of scope".
- Multi-tenant — one customer first; the data model stays single-tenant
  until it hurts.

## Changelog
- YYYY-MM-DD — initial map, N PROJs
```

Rules for the map:

- **One sentence of user outcome, no feature list.** The sentence says when
  the PROJ is done, not what is inside it. What is inside is
  `1_brainstorm/PROJ-<X>-concept.md`, and one list is enough.
- **`Depends on` is the only mechanic.** It is what lets `chain-guide` (0)
  say "PROJ-3 waits for PROJ-2" instead of that ordering living scattered
  across concept documents.
- **No estimates, no dates.** No skill reads them and they are wrong by the
  time anyone does.
- **Status:** `planned | concept | building | shipped | dropped`. Set to
  `concept` by `brainstorming` when it opens the PROJ, to `shipped` by
  `delivery` (8) on merge. Everything else is a manual product decision and
  gets a changelog line.

### 4. Confirm and commit

Play both files back. Then commit if the workspace is a git repo (it may
not be yet — the files are the durable artifact either way):

`docs: product vision — PRODUCT.md + roadmap (N PROJs)`

Run `bash scripts/curation-caps.sh` if it is already in the repo; otherwise
count: `docs/PRODUCT.md` must fit 30 non-blank lines. Over the cap means the
vision is carrying feature detail — cut it, never raise the cap.

→ NEXT ACTION: `brainstorming` (1) on the recommended first PROJ. If the
project has no scaffold yet, set it up first — `frontend-design` (1c) needs
a component directory and a route to render the showcase into, and the
component registry is generated from `src/components/**`.

## Revision Round

When the product direction changes, re-run this skill instead of editing the
map by hand:

- Only the changed part is re-interviewed; settled topics are not re-opened.
- Every change lands in the roadmap `## Changelog` with the date — a PROJ
  split, a reordering, a dropped PROJ, a retired non-goal.
- A PROJ already `building` or `shipped` is never rewritten. If it turns out
  wrong, mark it `dropped` with the reason and add its successor as a new
  numbered entry. Numbers are never reused.

## Output

- `docs/PRODUCT.md` — the curated product baseline (≤30 non-blank lines)
- `specs/product-roadmap.md` — the numbered PROJ map with dependencies

Consumed by: `brainstorming` (1) takes one map entry as its scope boundary
and inherits its siblings and exclusions · `chain-guide` (0) routes by
`Depends on` and `Status` · every context bundle carries `docs/PRODUCT.md`,
so implementers know what the product is · `intake` (0b) merges rather than
overwrites when it later runs on the same repo.

## Failure Behavior

- Non-goals stay vague after two rounds of pushing → write the map anyway,
  and record the vagueness explicitly in `## Not Now` as an open product
  decision with an owner. An unrecorded open scope is the expensive one.
- The user wants to start building immediately → write the map from what is
  known, mark unsettled entries `planned` with a one-line question in
  `## Not Now`, and hand off. This skill must never become the blocker; it
  must only make sure the question was asked once, in writing.

## Rules

- **Product level only** — technology, screens, and user stories belong to
  other skills, and every one of them here is a future contradiction.
- **Never overwrite** an existing `docs/PRODUCT.md` or roadmap entry —
  merge, and record retirements in the changelog.
- **Numbers are allocated once** and never reused.
- **English** — all documentation in English.
