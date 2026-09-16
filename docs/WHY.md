# Why This Works The Way It Does

This page is for anyone who isn't a developer but wants to understand
what this project actually does and — more importantly — *why* it's
built the way it is. No jargon, no script names, no step numbers. If you
want the technical version, see [skill-chain.md](skill-chain.md) (how it
works today) or `CONCEPT.md` (the full design rationale and history).

## What this is, in one sentence

A structured way of turning a rough idea into working, reviewed,
documented software using AI — with checks built in at every stage so
the AI's work can be trusted, instead of just hoping it got everything
right.

## The big picture

Think of it as an assembly line with two inspection points a human
actually has to sign off on, and a lot of automatic quality control in
between:

```
  idea  →  plan  →  ✋ human approves the plan  →  build  →  check  →  ✋ human approves the result  →  shipped
```

1. **Idea → plan.** The idea gets turned into a concept, then detailed
   requirements, then a technical plan — broken into small, ordered
   chunks of work.
2. **A person approves the plan.** Before any code is written, a human
   reviews the plan and either approves it or sends it back with
   feedback. This is the first of only two moments a human is asked to
   decide something.
3. **Build.** The AI writes the code, chunk by chunk, following the
   approved plan.
4. **Check.** Every chunk is tested and reviewed — by other AI models,
   by automated tools, and against a fixed checklist — before it's
   allowed to count as "done."
5. **A person approves the result.** The finished work becomes a pull
   request (a proposed change, ready to read and merge). A human reviews
   it and merges it. That's the second and last moment a human has to
   decide something.

Everything between those two human moments runs on its own — including
overnight. That's only possible because of the safeguards below.

## Why it's built this way

### We don't let the AI freewheel through the whole thing at once

An AI doing a big task in one long, unbroken session tends to lose track
of earlier decisions, contradict itself, or quietly cut corners the
longer it runs — much like a person trying to hold an entire project in
their head without ever writing anything down. So the work is split into
small, well-defined pieces (one piece of functionality at a time), and
each piece gets handled by a fresh AI "worker" that starts with a clean
slate: just this one task, the exact instructions for it, and nothing
else cluttering its attention. A worker that only needs to fix one small
problem is only ever shown that one problem — not the entire project's
history — so it can't get confused by, or waste effort re-reading,
things that have nothing to do with its job. This is also what keeps
costs down: a small, focused task is cheap to hand to an AI; a giant,
unfocused one is expensive and error-prone.

### Nobody grades their own exam

If the same AI that wrote some code is also the only one who checks it,
it tends to approve its own work — the same blind spots that caused the
mistake also stop it from noticing the mistake. So this project always
uses a *second, different* AI model to review anything a *first* AI
model produced, and vice versa. Neither one ever reviews its own
output. It's the same reason a second doctor's opinion is worth having
even when the first one seems confident.

### Automated tools do the boring, tireless checking

Two well-known code-quality tools do a lot of the heavy lifting:

- **CodeRabbit** automatically reviews every batch of new code the way a
  thorough human reviewer would — checking for bugs, bad patterns, and
  missed edge cases — every single time, without getting tired or
  skipping a diff because it's Friday afternoon.
- **Sonar** scans the finished work for security holes, code-quality
  problems, and risky patterns that are easy for a fast-moving process
  (human or AI) to miss, especially the kind of subtle issue that only
  shows up when you look at the *whole* codebase rather than one change
  at a time.

Both run automatically. Nothing moves forward until they're satisfied —
or a human has explicitly decided a remaining issue is acceptable to
carry forward.

### The paperwork is generated, not freehand

Things like the description of a proposed change, or the morning
summary of what happened overnight, are never written by the AI typing
freely. They're generated from a fixed template, filled in with actual
recorded facts (what was built, what passed, what didn't). This matters
because free-written text can be persuasive even when it's wrong or
incomplete — a confident paragraph can talk around a problem. A
generated report can't: if a check didn't pass, that fact is in the
data, so it shows up in the report, every time, the same way, whether
the AI "feels" like mentioning it or not.

### The process runs the same way every time

Every stage — planning, building, checking, shipping — follows the same
fixed checklist and the same fixed scripts, regardless of which AI model
is doing the work or how the previous run went. This is deliberate: we
cannot fully trust an AI to remember to do every step correctly on its
own, especially across a long, unattended run. A fixed structure means
the important steps happen because the *process* requires them, not
because the AI happened to think of them this time. A script either
passes or it doesn't — it can't be talked into skipping a check the way
a person or an AI sometimes can.

### It stops and asks, rather than guessing

If something goes wrong in a way the process doesn't have a defined
answer for — a check keeps failing, a tool isn't available, the plan
turns out to be contradictory — the run stops itself and leaves a clear
record of exactly what happened and where, instead of pushing forward
on a guess. A human then decides what to do. The only two things a human
is *routinely* asked to decide are the plan and the final result; being
asked anything outside of those two moments is the signal that
something needs real judgment, not more automation.

### Documentation is kept small on purpose

Long project documents that nobody updates become actively misleading —
worse than having no documentation at all, because people trust them
anyway. So the project's core documents (what the product is, how it's
built, the rules everyone follows) are kept deliberately short, and
updating them is a required part of finishing any piece of work, not an
occasional afterthought. A document that's cheap to keep current stays
current; a document that takes a day to update never gets updated.

## What "trust, but verify" looks like here

None of this exists because the AI is assumed to be bad at its job. It's
built this way because *any* fast-moving process — AI or human — makes
occasional mistakes, and the cost of catching a mistake early (a failed
check, a second reviewer, a blocked step) is always smaller than the
cost of finding it after it's shipped. The structure isn't there to slow
the AI down; it's there so the two human checkpoints can be brief and
still be meaningful, because everything in between has already been
checked several times over.

## Want more detail?

- [skill-chain.md](skill-chain.md) — the actual steps, in order, as they
  run today.
- `CONCEPT.md` (repo root) — the full technical design, the reasoning
  behind every decision, and what's still on the roadmap.
