---
name: bootstrap
description: "Turn an approved product vision into a running, empty project: decide the stack and record it as the single source of truth in docs/ARCHITECTURE.md § Stack, run the real scaffold command, verify build and tests are green, and write root AGENTS.md plus the CLAUDE.md pointer. Use when: (1) the product vision exists and the workspace has no application code yet, (2) an existing repo needs its stack recorded and its agent files created. Not for: an existing codebase with code to extract (use intake), product scope (use product-vision), PROJ-level tech design (use architecture), per-PROJ P0 setup (use setup)."
---

# Bootstrap — Stack, Scaffold, Agent Files

Between "we know what we are building" and "we can build it" sits a step no
skill owned: somebody has to decide the technology and stand up the empty
project. Without it `frontend-design` (1c) has no component directory and no
route to render the showcase into, the component registry generates from a
`src/components/**` that does not exist, and the stack ends up asserted in
half a dozen places instead of stated once.

This skill closes that gap. It runs ONCE per project, after
`product-vision` (0a) and before `brainstorming` (1).

**The stack is recorded in exactly one place: `docs/ARCHITECTURE.md`,
section `## Stack`.** Every skill that needs a stack fact reads it there.
`architecture` (3) inherits it and documents consequences — it never
re-opens the choice. No skill hardcodes a framework or a CSS library.

<HARD-GATE>
Never scaffold into a workspace that already has application code. A repo
with code is `0b_intake`'s job — extraction, not creation. Check first.
</HARD-GATE>

<HARD-GATE>
Never run a scaffold or install command the user has not seen and approved.
Print the exact command, wait for the go-ahead, then run it.
</HARD-GATE>

<HARD-GATE>
A scaffold that does not build is not a scaffold. `build` and `test` must
exit 0 before this skill seals. Do not hand off a broken baseline "for later".
</HARD-GATE>

## Input

- `docs/PRODUCT.md` and `specs/product-roadmap.md` from `product-vision` (0a).
  Without them, ask for the one-sentence product description before deciding
  anything — the stack follows from what is being built.
- Any constraint the user already stated: a hosting requirement, a language
  the team knows, an existing account, a customer's platform.

## Workflow

### 1. Decide the stack

Go layer by layer. For each: propose a default with **one line** of reasoning
from the product, and ask only where the product genuinely leaves it open.
Most layers answer themselves once the first two are set — do not turn this
into twelve questions.

| Layer | Decide | Notes |
|---|---|---|
| Language + runtime | | follows from the product and the team |
| Package manager | | one, project-wide |
| Framework | | web app, service, CLI, library — the product decides |
| Styling | only if there is a UI | |
| Component library | only if there is a UI | `frontend-design` (1c) themes it later, it does not pick it |
| Database + auth | only if state is persisted | |
| Tests | unit runner + e2e runner | e2e only if there is a UI |
| Lint + format | | one tool, no debate |
| Hosting | | may stay "not decided yet" — record it as open |

Rules:

- **Boring wins.** The chain reviews, gates, and QAs everything downstream;
  a stack nobody on the project knows makes every one of those steps slower.
- **A layer that is not needed is not chosen.** No database for a static
  site, no state library before there is state. "Not used" is a valid row.
- **Do not invent version numbers.** Decide majors; the exact versions get
  read out of the lockfile in step 3, after the install.
- **Undecidable is a valid outcome** for hosting or a provider — record it in
  the table as `open — decide before <PROJ-N>` rather than guessing.

### 2. Scaffold

1. Print the exact command(s) — the scaffold, then the install. Wait for approval.
2. Run them.
3. Add whatever the scaffold left out but the chain needs: the test runner,
   lint/format config, and **one trivial passing test**. A `test` script with
   no test proves nothing and the wave gate will trust it.
4. Verify, and show the real output:

```bash
<pm> run build     # must exit 0
<pm> test          # must exit 0
```

If a UI framework was chosen, also start the dev server once and confirm the
default page renders. A scaffold nobody looked at is a guess.

### 3. Record the stack

Create `docs/ARCHITECTURE.md` with `## Stack` as its FIRST section. Read the
versions from `package.json`/the lockfile — never from memory:

```markdown
# Architecture

## Stack
| Layer | Choice | Version | Notes |
|---|---|---|---|
| Runtime | Node | 22 | |
| Package manager | pnpm | 9 | project-wide, no npm/yarn |
| Framework | Next.js | 15 | App Router |
| Styling | Tailwind | 4 | tokens in `src/app/globals.css` |
| Components | shadcn/ui | | themed by `1c_frontend-design` |
| Database | Supabase Postgres | | RLS on by default |
| Auth | Supabase Auth | | |
| Tests | Vitest · Playwright | | unit · e2e |
| Lint/format | Biome | | |
| Hosting | open | | decide before PROJ-2 |

Commands: `pnpm dev` · `pnpm build` · `pnpm test` · `pnpm lint`

<!-- Everything below is filled by 3_architecture (per PROJ) and P7 curation. -->
```

This file is part of the curated baseline, is injected into every context
bundle, and is **capped at 200 lines** (`curation-caps.sh`). The Stack table
is the part that must never be duplicated elsewhere.

If `docs/ARCHITECTURE.md` already exists (a repo that went through
`0b_intake`), do not rewrite it — insert or correct the `## Stack` section
and leave everything else alone.

### 4. Write the agent files

**Root `AGENTS.md`** — durable agent rules, **≤40 non-blank lines**
(`curation-caps.sh`). Only what is true today; this is not a place for
aspirations:

```markdown
# <Product> — Agent Instructions

<One sentence: what this product is.> Full context: `docs/PRODUCT.md`.

## Stack
Authoritative in `docs/ARCHITECTURE.md` § Stack. Never assume a library
that is not listed there; never add one without an architecture decision.

## Commands
- `<pm> dev` · `<pm> build` · `<pm> test` · `<pm> lint`

## Curated context
- `docs/PRODUCT.md` — what the product is, and is not
- `docs/ARCHITECTURE.md` — stack + load-bearing architecture
- `docs/GUIDELINES.md` — conventions that ARE the rule
- `docs/DESIGN-SYSTEM.md` + `docs/components.md` — UI rules + registry
- `specs/product-roadmap.md` — PROJ map and order

## Rules
- <rules the user states now, or nothing — P7 curation grows this file>
```

**Root `CLAUDE.md`** — a pointer, never a second rulebook:

```markdown
# Claude Instructions

Must read and follow [AGENTS.md](./AGENTS.md) before making changes.
All durable agent instructions are curated in AGENTS.md only.
```

Codex reads `AGENTS.md` natively, so there is no third file. Two rule files
that drift are worse than one.

### 5. Seal

1. `git init` if the workspace is not a repo yet.
2. Run `bash scripts/curation-caps.sh` if it is already in the repo;
   otherwise count: `AGENTS.md` ≤40 non-blank lines,
   `docs/ARCHITECTURE.md` ≤200 lines.
3. Commit: `chore: project bootstrap — <framework> + <database or "no backend">`

→ NEXT ACTION: `brainstorming` (1) on the first PROJ of
`specs/product-roadmap.md`. The repo now has a real component directory, so
`frontend-design` (1c) writes into it instead of into a standalone HTML file.

## Completion Checklist

- [ ] No pre-existing application code was overwritten
- [ ] Every scaffold/install command was shown before it ran
- [ ] `build` and `test` exit 0, output shown, not claimed
- [ ] At least one real test exists (an empty test script is a false gate)
- [ ] `docs/ARCHITECTURE.md` § Stack written with versions read from the lockfile
- [ ] Root `AGENTS.md` within its cap; `CLAUDE.md` is a pointer only
- [ ] One bootstrap commit

## Failure Behavior

- The scaffold command fails → stop and report it. Do NOT hand-assemble the
  project file by file; a scaffold you built yourself is a stack nobody else
  can regenerate.
- `build` or `test` red after the scaffold → fix it here. This is the
  cheapest moment in the project's life to fix a broken toolchain, and every
  later gate assumes it is green.
- The user cannot decide a layer → record it as `open — decide before
  <PROJ-N>` in the Stack table and continue. An open row is honest; a guessed
  row gets treated as a decision by every skill downstream.

## Rules

- **One stack, one place** — `docs/ARCHITECTURE.md` § Stack. Anything that
  needs a stack fact reads it there; nothing restates it.
- **No product decisions** — scope belongs to `product-vision` (0a), features
  to `brainstorming` (1).
- **No feature code** — this skill produces an empty, running project. Not a
  single screen, not a single route beyond what the scaffold generates.
- **English** — all documentation in English.
