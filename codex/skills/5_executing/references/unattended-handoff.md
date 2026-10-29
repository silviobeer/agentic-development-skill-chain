# Unattended handoff (P0:done → runner)

Asked once per PROJ, in the lead, after P0 is sealed. Run from `.worktree.path`
with `<X> <theme>` filled in. `scripts/test-unattended-handoff.sh` executes both
blocks against stubs.

Run the probe. `SKIP` → continue silently. `ASK` → ask the user once (a
numbered question where there is no question tool), with its prerequisite lines
shown: "Run P5 to PR unattended (`runner/run-phase.sh auto <X> <theme>`), drive
it to the PR in this session (keep it going with `/goal`), or continue
interactively?" A missing prerequisite names what degrades or blocks; the
choice stays the user's.

- **Unattended** → run the launch block, print what it lists below, and end the
  turn: no polling, no further work here.
- **In this session** → follow `in-session-driver.md` from the Quality Gate to
  the PR and tell the user to set the `/goal` it names.
- **Interactive** → continue.

## Probe

Prints `SKIP` (no question: the runner's own P5 lane, or any phase other than
`P0:done`) or `ASK` plus one line per prerequisite. P0's `chain check preflight` already
hard-stops on `claude`, `coderabbit` (unless `coderabbit.enabled=false`) and (frontend waves) `agent-browser`; this checks only what
it does not.

```bash probe
S=specs/PROJ-<X>-<theme>/state.json
if [ "${SKILLCHAIN_RUNNER_MANAGED:-}" = 1 ] || [ "$(jq -r '.phase + ":" + .status' "$S" 2>/dev/null)" != P0:done ]; then
  echo SKIP
else
  echo ASK
  { command -v codex >/dev/null && codex login status >/dev/null 2>&1; } \
    && echo "codex: ok" \
    || echo "codex: missing or unauthenticated -> single-provider run, flagged in the morning report and PR body"
  if [ "${SKILLCHAIN_SKIP_PERMISSIONS:-}" = 1 ]; then   # explicit opt-in: full bypass
    off=; for f in ~/.claude/settings.json .claude/settings.json .claude/settings.local.json /etc/claude-code/managed-settings.json; do
      jq -e '.permissions.disableBypassPermissionsMode == "disable"' "$f" >/dev/null 2>&1 && off=1
    done
    [ -z "$off" ] && echo "permissions: ok" || echo "permissions: bypass mode disabled -> the claude lane stops at its first prompt"
  else                                                   # default: project allowlist
    jq -e '(.permissions.allow // []) | length > 0' .claude/settings.json >/dev/null 2>&1 \
      && echo "permissions: ok" \
      || echo "permissions: no project allowlist -> run scripts/merge-project-settings.sh, or the claude lane is denied its first command"
  fi
  RUN="${SKILLCHAIN_RUNNER:-$(for c in runner/run-phase.sh ~/.claude/skills/5_executing/runner/run-phase.sh ~/.codex/skills/5_executing/runner/run-phase.sh; do [ -x "$c" ] && { echo "$c"; break; }; done)}"
  [ -x "$RUN" ] && echo "runner: ok" \
    || echo "runner: NOT FOUND (unattended only) -> run the chain's install script, or set SKILLCHAIN_RUNNER=<path>/run-phase.sh"
fi
```

## Launch

Detached, never a foreground Bash call: a foreground call is capped at 10 minutes
and a background call at 2 hours, and an overnight run outlives both.

The claude writer lane runs under the project's `.claude/settings.json`
permissions. Only when the user explicitly opts into full bypass, export
`SKILLCHAIN_SKIP_PERMISSIONS=1` before this block (`setup.md` §2, Claude host);
never set it on the user's behalf.

```bash launch
RUN="${SKILLCHAIN_RUNNER:-$(for c in runner/run-phase.sh ~/.claude/skills/5_executing/runner/run-phase.sh ~/.codex/skills/5_executing/runner/run-phase.sh; do [ -x "$c" ] && { echo "$c"; break; }; done)}"
LOG="$(mktemp "${TMPDIR:-/tmp}/skillchain-auto-PROJ-<X>.XXXXXX")"
S=(setsid); command -v setsid >/dev/null || S=(perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' --)  # macOS has no setsid
"${S[@]}" nohup "$RUN" auto <X> <theme> >"$LOG" 2>&1 </dev/null &
echo "log: $LOG  pid: $!"
```

Then print, and end the turn (the waiting session never polls):

- the log path and `pid`; stop the run with `kill -TERM -- -<pid>` (the runner kills both lane process groups)
- progress: `jq -r '.phase + ":" + .status' specs/PROJ-<X>-<theme>/state.json`, or `chain render report morning specs` (the installed `5_executing/scripts/chain`)
- after a stop: `bash scripts/chain state transition <X> <theme> <phase> running`, then relaunch the block above
