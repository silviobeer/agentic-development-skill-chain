# Systematic Debugging

Reference for when something breaks during execution. Load when a test fails, behavior is unexpected, or a fix attempt didn't work.

**Core principle:** Find root cause before attempting fixes. Symptom fixes are failure.

## The Four Phases

Complete each phase before moving to the next.

### Phase 1: Root Cause Investigation

BEFORE attempting ANY fix:

1. **Read error messages carefully** — full stack traces, line numbers, error codes. Don't skip past them.
2. **Reproduce consistently** — exact steps, every time. If not reproducible, gather more data instead of guessing.
3. **Check recent changes** — git diff, recent commits, new dependencies, config changes.
4. **Trace data flow backward** — where does the bad value originate? What called this with the bad value? Keep tracing up until you find the source. Fix at source, not at symptom.

**For multi-component systems:** Add diagnostic logging at each component boundary. Run once to gather evidence showing WHERE it breaks. Then investigate that specific component.

### Phase 2: Pattern Analysis

1. Find similar **working code** in the same codebase
2. Compare working vs broken — list every difference, however small
3. Don't assume "that can't matter"

### Phase 3: Hypothesis and Testing

1. **Form a single hypothesis** — "I think X is the root cause because Y"
2. **Test minimally** — smallest possible change, one variable at a time
3. **Verify** — did it work? Yes → Phase 4. No → new hypothesis. Do NOT stack fixes on top of each other.

### Phase 4: Fix

1. Write a failing test that reproduces the bug
2. Implement a single fix addressing the root cause
3. Verify: test passes, no other tests broken
4. If fix doesn't work and you've tried 3+ fixes → **stop and escalate to the user**. This is likely an architectural problem, not a bug.

## Root Cause Tracing

When the error appears deep in the call stack:

```
Symptom: error at Layer 4
  ← called by Layer 3 (what value was passed?)
    ← called by Layer 2 (where did that value come from?)
      ← called by Layer 1 (THIS is the source — fix here)
```

**Never fix just where the error appears.** Trace backward to the original trigger.

**Adding instrumentation when you can't trace manually:**
- Log before the problematic operation, not after it fails
- Include: input values, cwd, environment variables, stack trace (`new Error().stack`)
- In tests: use `console.error()` not logger (logger may be suppressed)

## Red Flags — Return to Phase 1

If you catch yourself thinking:
- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "I don't fully understand but this might work"
- "It's probably X, let me fix that"
- Proposing solutions before tracing data flow
- Stacking multiple fixes without isolating which one works

## Escalation Rules

- **< 3 fix attempts failed:** Return to Phase 1, re-analyze with new information
- **3+ fix attempts failed:** Stop. This is likely an architectural problem. Escalate to user before attempting more fixes.
- **Root cause is in the spec/architecture:** Escalate to user — this isn't a code fix.
