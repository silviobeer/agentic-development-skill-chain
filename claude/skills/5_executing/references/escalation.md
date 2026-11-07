# Escalation (blockers that need a human)

A blocker is anything the run cannot repair itself: missing or expired token, missing tool or Sonar
configuration, failed auth, exit 76 (`blocked_external`), a spec or architecture contradiction, Outer
Ralph exhausted. The cost of a blocker is the time until a human knows about it, so the lead escalates
the moment it sees one. It never parks silently and never waits for the user to look.

## Classify first

- **Self-fixable** (stale lockfile, missing script copy, transient probe failure): fix and retry once;
  no escalation.
- **Human-required** (everything above): escalate now, as below.

## Escalate in one step

1. **Collect everything.** Report every hard failure found in one go (`.stop.reason` lists all of them,
   each with its fix), so one answer unblocks the run instead of one stop per failure.
2. **Notify twice.** Send a push/desktop notification if the host has one (Claude: `PushNotification`),
   and in the same turn put the chat message below as the turn's last output.
3. **Message format**, short and complete:
   `BLOCKED <PROJ-X> <phase>` · cause (verbatim error line) · what is needed from the user (exact
   command or value) · options: `fix and resume` / `continue degraded` (only if the gate allows it) /
   `abort`.
4. **Park, then end the turn.** `chain state` carries the blocked phase and reason and the stop report
   is rendered. Do not poll. Independent work (other stories, not the blocked gate)
   continues until it needs the blocker.
5. **Remind, bounded.** If the host can schedule a one-shot wakeup (Claude: `CronCreate`), schedule
   reminders at +15, +45 and +105 minutes that re-send the push notification with the one-line
   cause, nothing else. No scheduler (Codex): skip and say so in the message. Cancel pending
   reminders the moment the user answers or the phase leaves `blocked`; after the third, stop and
   leave the parked state as the record. A reminder never acts on the blocker.
6. **Unattended runs** have no chat: the stop report and the runner's non-zero exit are the
   notification (the runner also sends a best-effort desktop notification at the end; no reminders). The next interactive lead start reads `.stop` and opens with step 3.

## Resume

After the user fixes the cause, re-enter the blocked phase (`P0:blocked` → rerun setup; idempotent).
Never unset `degraded` or bypass the failed gate by hand.
