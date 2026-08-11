#!/usr/bin/env bash
# Deterministic behavior tests for the persistent PROJ worktree helper.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/codex/skills/4b_setup/scripts/worktree.sh"
STATE_SOURCE="$ROOT/codex/skills/4b_setup/scripts/state.sh"
PLAN_FIXTURES="$ROOT/scripts/fixtures/wave-plan-validator"
TMP_ROOT="$(mktemp -d)"
cleanup_tmp() { rm -rf "$TMP_ROOT"; }
trap cleanup_tmp EXIT

PASS=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { PASS=$((PASS + 1)); echo "ok $PASS - $*"; }

init_repo() { # path proj theme env-mode [remote]
  local repo="$1" proj="$2" theme="$3" env_mode="$4" remote="${5:-}"
  mkdir -p "$repo/specs/PROJ-${proj}-${theme}/3-4_plan" "$repo/scripts"
  cp "$STATE_SOURCE" "$repo/scripts/state.sh"
  cp "$PLAN_FIXTURES/plan-valid.md" "$repo/specs/PROJ-${proj}-${theme}/3-4_plan/PROJ-${proj}-wave-1-plan.md"
  cp "$PLAN_FIXTURES/config-valid.json" "$repo/specs/PROJ-${proj}-${theme}/3-4_plan/wave-gate-config.json"
  chmod +x "$repo/scripts/state.sh"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.name Test
  git -C "$repo" config user.email test@example.invalid
  case "$env_mode" in
    ignored)
      printf '.env.local\nnode_modules/\n' >"$repo/.gitignore"
      printf 'SECRET=not-logged\n' >"$repo/.env.local"
      ;;
    example)
      printf '.env.local\n' >"$repo/.gitignore"
      : >"$repo/.env.local.example"
      ;;
    unignored) printf 'SECRET=not-logged\n' >"$repo/.env.local" ;;
    absent) : ;;
    *) fail "unknown env mode $env_mode" ;;
  esac
  printf '.state.lock\n' >>"$repo/.gitignore"
  (cd "$repo" && bash scripts/state.sh init "$proj" "$theme" >/dev/null)
  (cd "$repo" && bash scripts/state.sh transition "$proj" "$theme" CP1 running >/dev/null)
  (cd "$repo" && bash scripts/state.sh transition "$proj" "$theme" CP1 approved >/dev/null)
  git -C "$repo" add -A
  git -C "$repo" commit -qm "CP1 approved"
  if [ -n "$remote" ]; then
    git init -q --bare "$remote"
    git -C "$repo" remote add origin "$remote"
    git -C "$repo" push -q -u origin main
  fi
}

advance_to_p8_done() { # worktree proj theme
  local wt="$1" proj="$2" theme="$3" phase
  for phase in P0 P5 P6 P7 P8; do
    (cd "$wt" && bash scripts/state.sh transition "$proj" "$theme" "$phase" running >/dev/null)
    if [ "$phase" = P8 ]; then
      (cd "$wt" && bash scripts/state.sh set "$proj" "$theme" .pr '{"number":1,"url":"https://example.invalid/pr/1","ci":"green"}' >/dev/null)
      (cd "$wt" && bash scripts/state.sh set "$proj" "$theme" .worktree.cleanup_status '"removed"' >/dev/null)
      (cd "$wt" && bash scripts/state.sh set "$proj" "$theme" .worktree.cleanup_reason '"removed after final CI, upstream-head, and clean-tree verification"' >/dev/null)
    fi
    (cd "$wt" && bash scripts/state.sh transition "$proj" "$theme" "$phase" done >/dev/null)
  done
  git -C "$wt" add -A
  git -C "$wt" commit -qm "P8 seal"
  git -C "$wt" push -q -u origin "proj/PROJ-${proj}"
}

# Create + resume: exact sibling path, isolated env/dependencies, and state.
repo="$TMP_ROOT/create/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 3 alpha ignored
fake_bin="$TMP_ROOT/fake-bin"
mkdir -p "$fake_bin"
apply_fake_npm="$fake_bin/npm"
printf '#!/usr/bin/env bash\n[ "$1" = ci ] || exit 9\nif [ -e .env.local ] || [ -L .env.local ]; then echo ENV_WAS_VISIBLE >&2; exit 8; fi\nmkdir -p node_modules\nprintf installed > node_modules/.proof\n' >"$apply_fake_npm"
chmod +x "$apply_fake_npm"
printf '{"name":"fixture","private":true}\n' >"$repo/package.json"
printf '{"name":"fixture","lockfileVersion":3,"packages":{}}\n' >"$repo/package-lock.json"
git -C "$repo" add package.json package-lock.json
git -C "$repo" commit -qm "add lockfile"
wt="$(cd "$repo" && PATH="$fake_bin:$PATH" "$HELPER" prepare 3 alpha)"
[ "$wt" = "$TMP_ROOT/create/control-proj3" ] || fail "unexpected default worktree path: $wt"
[ "$(git -C "$wt" branch --show-current)" = proj/PROJ-3 ] || fail "wrong worktree branch"
[ -L "$wt/.env.local" ] || fail ".env.local is not a symlink"
[ "$(readlink "$wt/.env.local")" = "$repo/.env.local" ] || fail ".env.local link source is wrong"
[ -d "$wt/node_modules" ] && [ ! -L "$wt/node_modules" ] || fail "node_modules is not isolated"
jq -e --arg c "$repo" --arg w "$wt" '
  .base_sha and .branch == "proj/PROJ-3"
  and .worktree.control_path == $c and .worktree.path == $w
  and .worktree.env_link_status == "linked"
  and .worktree.database_mode == "shared"
  and .worktree.dependency_install == "installed"
  and .worktree.cleanup_status == "pending"
' "$wt/specs/PROJ-3-alpha/state.json" >/dev/null || fail "worktree state metadata invalid"
resume_output="$(cd "$repo" && PATH="$fake_bin:$PATH" "$HELPER" prepare 3 alpha 2>&1)"
wt_again="$(tail -n 1 <<<"$resume_output")"
[ "$wt_again" = "$wt" ] || fail "resume did not return the same path"
if grep -F 'SECRET=not-logged' <<<"$resume_output" >/dev/null; then fail "secret value leaked in prepare output"; fi
if (cd "$wt" && bash scripts/state.sh set 3 alpha .worktree.dev_port '"bad"' >/dev/null 2>&1); then fail "state.sh accepted invalid worktree metadata"; fi
[ "$(jq -r .worktree.dev_port "$wt/specs/PROJ-3-alpha/state.json")" = null ] || fail "invalid state mutation changed worktree metadata"
ok "prepare creates and idempotently resumes an isolated persistent worktree"

fail_install_bin="$TMP_ROOT/fail-install-bin"
mkdir -p "$fail_install_bin"
printf '#!/usr/bin/env bash\nif [ -e .env.local ] || [ -L .env.local ]; then echo ENV_WAS_VISIBLE >&2; exit 43; fi\nexit 42\n' >"$fail_install_bin/npm"
chmod +x "$fail_install_bin/npm"
if (cd "$repo" && PATH="$fail_install_bin:$PATH" "$HELPER" prepare 3 alpha >"$TMP_ROOT/install-fail.out" 2>&1); then fail "failing dependency installer was accepted"; fi
[ -L "$wt/.env.local" ] && [ "$(readlink "$wt/.env.local")" = "$repo/.env.local" ] || fail "failed installer did not restore managed env link"
if grep -F 'SECRET=not-logged' "$TMP_ROOT/install-fail.out" >/dev/null; then fail "failing installer output leaked secret value"; fi
if grep -F 'ENV_WAS_VISIBLE' "$TMP_ROOT/install-fail.out" >/dev/null; then fail "managed env was visible to failing installer"; fi
ok "failed dependency install restores validated env state without exposing secrets"

rm -f "$repo/.env.local"
if (cd "$repo" && PATH="$fake_bin:$PATH" "$HELPER" prepare 3 alpha >"$TMP_ROOT/env-resume.out" 2>&1); then fail "resume accepted a stale env symlink"; fi
grep -F "stale or unmanaged" "$TMP_ROOT/env-resume.out" >/dev/null || fail "stale env refusal was not explicit"
[ "$(jq -r .worktree.env_link_status "$wt/specs/PROJ-3-alpha/state.json")" = linked ] || fail "failed resume wrote false env state"
ok "resume rejects a stale env symlink instead of recording not_present"

# Occupied target and env safety checks fail before a worktree is registered.
repo="$TMP_ROOT/occupied/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 4 beta absent
mkdir -p "$TMP_ROOT/occupied/control-proj4"
if (cd "$repo" && "$HELPER" prepare 4 beta >/dev/null 2>&1); then fail "occupied target was accepted"; fi
[ -z "$(git -C "$repo" worktree list --porcelain | awk '$1=="branch" && $2=="refs/heads/proj/PROJ-4"')" ] || fail "occupied target left a worktree"
ok "prepare rejects an occupied unregistered target"

repo="$TMP_ROOT/example/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 5 gamma example
if (cd "$repo" && "$HELPER" prepare 5 gamma >/dev/null 2>&1); then fail "example-only env was accepted"; fi
ok "prepare blocks when only .env.local.example exists"

repo="$TMP_ROOT/unignored/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 6 delta unignored
if (cd "$repo" && "$HELPER" prepare 6 delta >/dev/null 2>&1); then fail "unignored env was accepted"; fi
ok "prepare rejects an unignored .env.local"

repo="$TMP_ROOT/invalid-plan/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 11 invalid absent
cp "$PLAN_FIXTURES/config-missing-regression.json" "$repo/specs/PROJ-11-invalid/3-4_plan/wave-gate-config.json"
git -C "$repo" add specs/PROJ-11-invalid/3-4_plan/wave-gate-config.json
git -C "$repo" commit -qm "introduce plan drift"
if (cd "$repo" && "$HELPER" prepare 11 invalid >/dev/null 2>&1); then fail "invalid wave plan was accepted"; fi
git -C "$repo" show-ref --verify --quiet refs/heads/proj/PROJ-11 && fail "plan failure created the PROJ branch"
ok "prepare runs the wave-plan validator before creating anything"

repo="$TMP_ROOT/not-approved/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 21 rho absent
(cd "$repo" && bash scripts/state.sh transition 21 rho P0 running >/dev/null)
git -C "$repo" add specs/PROJ-21-rho/state.json && git -C "$repo" commit -qm "state already advanced"
if (cd "$repo" && "$HELPER" prepare 21 rho >/dev/null 2>&1); then fail "non-CP1-approved state was accepted"; fi
git -C "$repo" show-ref --verify --quiet refs/heads/proj/PROJ-21 && fail "state failure created the PROJ branch"
ok "prepare requires CP1:approved in the committed control HEAD"

repo="$TMP_ROOT/tag-conflict/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 23 sigma absent
old_head="$(git -C "$repo" rev-parse HEAD)"
git -C "$repo" commit -q --allow-empty -m "new CP1 head"
git -C "$repo" tag proj-PROJ-23-base "$old_head"
if (cd "$repo" && "$HELPER" prepare 23 sigma >/dev/null 2>&1); then fail "conflicting base tag was accepted"; fi
git -C "$repo" show-ref --verify --quiet refs/heads/proj/PROJ-23 && fail "tag conflict left a branch"
[ ! -e "$TMP_ROOT/tag-conflict/control-proj23" ] || fail "tag conflict left a target path"
ok "base-tag conflicts fail before branch/worktree creation"

repo="$TMP_ROOT/lockfile-conflict/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 24 upsilon absent
printf '{"name":"fixture","private":true}\n' >"$repo/package.json"
printf '{"name":"fixture","lockfileVersion":3,"packages":{}}\n' >"$repo/package-lock.json"
: >"$repo/yarn.lock"
git -C "$repo" add package.json package-lock.json yarn.lock && git -C "$repo" commit -qm "conflicting lockfiles"
if (cd "$repo" && "$HELPER" prepare 24 upsilon >/dev/null 2>&1); then fail "multiple lockfiles were accepted"; fi
git -C "$repo" show-ref --verify --quiet refs/heads/proj/PROJ-24 && fail "lockfile conflict left a branch"
ok "prepare rejects ambiguous reproducible dependency installers"

repo="$TMP_ROOT/dirty-root/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 25 phi absent
printf dirty >"$repo/untracked.txt"
if (cd "$repo" && "$HELPER" prepare 25 phi >/dev/null 2>&1); then fail "dirty control checkout was accepted"; fi
rm -f "$repo/untracked.txt"
mkdir -p "$repo/subdir"
if (cd "$repo/subdir" && "$HELPER" prepare 25 phi >/dev/null 2>&1); then fail "non-root prepare was accepted"; fi
ok "prepare requires a clean control-checkout root"

# Explicit root and shared-resource lock default/override.
repo="$TMP_ROOT/custom/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 7 epsilon absent
custom_root="$TMP_ROOT/custom-worktrees"
wt="$(cd "$repo" && SKILLCHAIN_WORKTREE_ROOT="$custom_root" "$HELPER" prepare 7 epsilon)"
[ "$wt" = "$custom_root/control-proj7" ] || fail "SKILLCHAIN_WORKTREE_ROOT was ignored"
(cd "$wt" && "$HELPER" with-shared-lock -- sh -c 'printf locked > lock-proof')
[ -f "$wt/lock-proof" ] || fail "locked command did not run"
common="$(git -C "$wt" rev-parse --git-common-dir)"
case "$common" in /*) : ;; *) common="$wt/$common" ;; esac
[ -f "$(realpath -m "$common")/skillchain-shared-resources.lock" ] || fail "default common-dir lock missing"
override="$TMP_ROOT/custom-locks/auth.lock"
(cd "$wt" && SKILLCHAIN_SHARED_RESOURCE_LOCK="$override" "$HELPER" with-shared-lock -- true)
[ -f "$override" ] || fail "override lock missing"
exec 7>"$(realpath -m "$common")/skillchain-shared-resources.lock"
flock 7
set +e
(cd "$repo" && "$HELPER" with-shared-lock --timeout 0 -- true >/dev/null 2>&1)
lock_rc=$?
set -e
flock -u 7
[ "$lock_rc" -eq 73 ] || fail "control/worktree callers did not contend on the common-dir lock"
if (cd "$wt" && SKILLCHAIN_SHARED_RESOURCE_LOCK=relative.lock "$HELPER" with-shared-lock -- true >/dev/null 2>&1); then fail "relative shared-lock override was accepted"; fi
ok "custom worktree root and shared-resource lock contract work"

# Successful cleanup: P8 seal, identical upstream and CI head, clean tree.
repo="$TMP_ROOT/cleanup/control"
remote="$TMP_ROOT/cleanup/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 8 zeta ignored "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 8 zeta)"
advance_to_p8_done "$wt" 8 zeta
mkdir -p "$wt/packages/example/node_modules/pkg"
printf generated >"$wt/packages/example/node_modules/pkg/index.js"
head="$(git -C "$wt" rev-parse HEAD)"
(cd "$repo" && "$HELPER" cleanup 8 zeta --ci-verified-head "$head")
[ ! -e "$wt" ] || fail "successful cleanup kept worktree directory"
git -C "$repo" show-ref --verify --quiet refs/heads/proj/PROJ-8 || fail "cleanup deleted the PROJ branch"
[ "$(git -C "$repo" show proj/PROJ-8:specs/PROJ-8-zeta/state.json | jq -r .worktree.cleanup_status)" = removed ] || fail "durable removed status missing"
ok "cleanup removes only a clean, pushed, final-CI-verified worktree and keeps the branch"

repo="$TMP_ROOT/ignored-payload/control"
remote="$TMP_ROOT/ignored-payload/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 22 tau absent "$remote"
printf '.cache/\n' >>"$repo/.gitignore"
git -C "$repo" add .gitignore && git -C "$repo" commit -qm "ignore build cache"
wt="$(cd "$repo" && "$HELPER" prepare 22 tau)"
advance_to_p8_done "$wt" 22 tau
mkdir -p "$wt/.cache" && printf evidence >"$wt/.cache/result.bin"
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 22 tau --ci-verified-head "$head" >/dev/null 2>&1); then fail "unexpected ignored payload was deleted"; fi
[ -f "$wt/.cache/result.bin" ] || fail "unexpected ignored payload was lost"
jq -e '.worktree.cleanup_reason | contains("unexpected ignored payloads") and contains(".cache/")' "$wt/specs/PROJ-22-tau/state.json" >/dev/null || fail "ignored payload retention reason missing"
ok "cleanup permits dependency/state-lock artifacts but retains unexpected ignored evidence"

# A caller-provided SHA cannot substitute for state-backed green CI evidence.
repo="$TMP_ROOT/ci-red/control"
remote="$TMP_ROOT/ci-red/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 10 theta absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 10 theta)"
advance_to_p8_done "$wt" 10 theta
(cd "$wt" && bash scripts/state.sh set 10 theta .pr.ci '"red"' >/dev/null)
git -C "$wt" add specs/PROJ-10-theta/state.json
git -C "$wt" commit -qm "record red CI"
git -C "$wt" push -q
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 10 theta --ci-verified-head "$head" >/dev/null 2>&1); then fail "cleanup accepted red CI state"; fi
[ "$(jq -r .worktree.cleanup_status "$wt/specs/PROJ-10-theta/state.json")" = retained ] || fail "red CI did not retain worktree"
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-10-theta/state.json")" = "state does not record final CI as green" ] || fail "red CI reason missing"
ok "cleanup requires both a verified head argument and green CI state"

# Remaining cleanup protection classes: lifecycle/intent, verified head,
# upstream identity, and recorded topology. Each must preserve the worktree
# and write an exact retained reason through state.sh when the path is known.
repo="$TMP_ROOT/not-p8/control"
remote="$TMP_ROOT/not-p8/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 13 iota absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 13 iota)"
(cd "$wt" && bash scripts/state.sh set 13 iota .pr '{"number":1,"url":"https://example.invalid/pr/1","ci":"green"}' >/dev/null)
(cd "$wt" && bash scripts/state.sh set 13 iota .worktree.cleanup_status '"removed"' >/dev/null)
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 13 iota --ci-verified-head "$head" >/dev/null 2>&1); then fail "non-P8 state was cleaned"; fi
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-13-iota/state.json")" = "state is not P8:done" ] || fail "non-P8 reason missing"
ok "cleanup refuses lifecycle state other than P8:done"

repo="$TMP_ROOT/pending-intent/control"
remote="$TMP_ROOT/pending-intent/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 14 kappa absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 14 kappa)"
advance_to_p8_done "$wt" 14 kappa
(cd "$wt" && bash scripts/state.sh set 14 kappa .worktree.cleanup_status '"pending"' >/dev/null)
git -C "$wt" add specs/PROJ-14-kappa/state.json && git -C "$wt" commit -qm "remove cleanup intent" && git -C "$wt" push -q
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 14 kappa --ci-verified-head "$head" >/dev/null 2>&1); then fail "pending cleanup intent was accepted"; fi
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-14-kappa/state.json")" = "cleanup was not sealed as removed in the final P8 commit" ] || fail "intent reason missing"
ok "cleanup requires removed intent in the sealed state"

repo="$TMP_ROOT/head-mismatch/control"
remote="$TMP_ROOT/head-mismatch/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 15 lambda absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 15 lambda)"
advance_to_p8_done "$wt" 15 lambda
if (cd "$repo" && "$HELPER" cleanup 15 lambda --ci-verified-head 0000000000000000000000000000000000000000 >/dev/null 2>&1); then fail "mismatched CI head was accepted"; fi
jq -e '.worktree.cleanup_reason | startswith("final CI verified 000000")' "$wt/specs/PROJ-15-lambda/state.json" >/dev/null || fail "CI-head mismatch reason missing"
ok "cleanup binds final CI evidence to the exact local HEAD"

repo="$TMP_ROOT/no-upstream/control"
remote="$TMP_ROOT/no-upstream/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 16 mu absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 16 mu)"
advance_to_p8_done "$wt" 16 mu
git -C "$wt" branch --unset-upstream
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 16 mu --ci-verified-head "$head" >/dev/null 2>&1); then fail "missing upstream was accepted"; fi
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-16-mu/state.json")" = "PROJ branch has no remote-tracking upstream" ] || fail "missing-upstream reason missing"
ok "cleanup refuses a branch without upstream"

repo="$TMP_ROOT/local-upstream/control"
remote="$TMP_ROOT/local-upstream/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 26 chi absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 26 chi)"
advance_to_p8_done "$wt" 26 chi
git -C "$wt" config branch.proj/PROJ-26.remote .
git -C "$wt" config branch.proj/PROJ-26.merge refs/heads/proj/PROJ-26
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 26 chi --ci-verified-head "$head" >/dev/null 2>&1); then fail "local upstream was accepted as pushed evidence"; fi
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-26-chi/state.json")" = "PROJ branch has no remote-tracking upstream" ] || fail "local-upstream reason missing"
ok "cleanup rejects local upstreams as proof of a pushed commit"

repo="$TMP_ROOT/upstream-mismatch/control"
remote="$TMP_ROOT/upstream-mismatch/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 17 nu absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 17 nu)"
advance_to_p8_done "$wt" 17 nu
printf local >"$wt/local-only.txt"
git -C "$wt" add local-only.txt && git -C "$wt" commit -qm "local only"
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 17 nu --ci-verified-head "$head" >/dev/null 2>&1); then fail "mismatched upstream was accepted"; fi
jq -e '.worktree.cleanup_reason | startswith("upstream ") and contains("does not match local HEAD")' "$wt/specs/PROJ-17-nu/state.json" >/dev/null || fail "upstream mismatch reason missing"
ok "cleanup requires upstream to equal the verified local HEAD"

repo="$TMP_ROOT/stale-tracking/control"
remote="$TMP_ROOT/stale-tracking/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 29 aleph absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 29 aleph)"
advance_to_p8_done "$wt" 29 aleph
head="$(git -C "$wt" rev-parse HEAD)"
stale_tracking="$(git -C "$wt" rev-parse '@{upstream}')"
[ "$stale_tracking" = "$head" ] || fail "fixture upstream was not initially current"
git --git-dir="$remote" update-ref refs/heads/proj/PROJ-29 "$(git -C "$repo" rev-parse main)"
[ "$(git -C "$wt" rev-parse '@{upstream}')" = "$head" ] || fail "fixture did not preserve a stale local tracking ref"
if (cd "$repo" && "$HELPER" cleanup 29 aleph --ci-verified-head "$head" >/dev/null 2>&1); then fail "stale remote-tracking cache hid authoritative remote drift"; fi
jq -e '.worktree.cleanup_reason | startswith("upstream ") and contains("does not match local HEAD")' "$wt/specs/PROJ-29-aleph/state.json" >/dev/null || fail "authoritative remote mismatch reason missing"
ok "cleanup compares FETCH_HEAD instead of trusting stale remote-tracking state"

repo="$TMP_ROOT/path-mismatch/control"
remote="$TMP_ROOT/path-mismatch/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 18 xi absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 18 xi)"
advance_to_p8_done "$wt" 18 xi
(cd "$wt" && bash scripts/state.sh set 18 xi .worktree.path '"/definitely/not/the/registered/path"' >/dev/null)
git -C "$wt" add specs/PROJ-18-xi/state.json && git -C "$wt" commit -qm "corrupt topology" && git -C "$wt" push -q
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 18 xi --ci-verified-head "$head" >/dev/null 2>&1); then fail "mismatched recorded path was accepted"; fi
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-18-xi/state.json")" = "registered path does not match state.worktree.path" ] || fail "path mismatch reason missing"
ok "cleanup validates recorded path/registration topology"

repo="$TMP_ROOT/branch-mismatch/control"
remote="$TMP_ROOT/branch-mismatch/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 19 omicron absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 19 omicron)"
advance_to_p8_done "$wt" 19 omicron
(cd "$wt" && bash scripts/state.sh set 19 omicron .worktree.branch '"proj/PROJ-999"' >/dev/null)
git -C "$wt" add specs/PROJ-19-omicron/state.json && git -C "$wt" commit -qm "corrupt branch metadata" && git -C "$wt" push -q
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 19 omicron --ci-verified-head "$head" >/dev/null 2>&1); then fail "mismatched recorded branch was accepted"; fi
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-19-omicron/state.json")" = "registered branch does not match state.worktree.branch" ] || fail "branch mismatch reason missing"
ok "cleanup validates recorded branch topology"

repo="$TMP_ROOT/registration-conflict/control"
remote="$TMP_ROOT/registration-conflict/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 20 pi absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 20 pi)"
advance_to_p8_done "$wt" 20 pi
git -C "$wt" checkout -q --detach
head="$(git -C "$wt" rev-parse HEAD)"
if (cd "$repo" && "$HELPER" cleanup 20 pi --ci-verified-head "$head" >"$TMP_ROOT/registration.out" 2>&1); then fail "detached registration was accepted"; fi
[ -d "$wt" ] || fail "registration conflict removed the worktree"
grep -F "worktree retained: proj branch is not registered" "$TMP_ROOT/registration.out" >/dev/null || fail "registration conflict was not explicit"
[ "$(jq -r .worktree.cleanup_status "$wt/specs/PROJ-20-pi/state.json")" = retained ] || fail "detached registration did not mark retained"
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-20-pi/state.json")" = "proj branch is not registered to its recorded worktree (detached or conflicting registration)" ] || fail "detached registration reason missing"
ok "cleanup retains contradictory worktree registration with exact state-backed reason"

# Dirty cleanup is retained with a state.sh-authored exact reason.
repo="$TMP_ROOT/retained/control"
remote="$TMP_ROOT/retained/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 9 eta absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 9 eta)"
advance_to_p8_done "$wt" 9 eta
head="$(git -C "$wt" rev-parse HEAD)"
printf dirty >"$wt/untracked.txt"
if (cd "$repo" && "$HELPER" cleanup 9 eta --ci-verified-head "$head" >/dev/null 2>&1); then fail "dirty cleanup succeeded"; fi
[ -d "$wt" ] || fail "dirty worktree was removed"
[ "$(jq -r .worktree.cleanup_status "$wt/specs/PROJ-9-eta/state.json")" = retained ] || fail "retained status missing"
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-9-eta/state.json")" = "worktree has tracked or untracked changes" ] || fail "retained reason is not exact"
[ "$(jq -r '.phase + ":" + .status' "$wt/specs/PROJ-9-eta/state.json")" = P8:blocked ] || fail "retained P8 cleanup was not made resumable"
ok "cleanup retains dirty worktrees and records the exact reason through state.sh"

if (cd "$repo" && "$HELPER" prepare 9 eta >/dev/null 2>&1); then fail "late P0 prepare reset an advanced retained worktree"; fi
[ "$(jq -r .worktree.cleanup_status "$wt/specs/PROJ-9-eta/state.json")" = retained ] || fail "late prepare erased retained status"
[ "$(jq -r .worktree.cleanup_reason "$wt/specs/PROJ-9-eta/state.json")" = "worktree has tracked or untracked changes" ] || fail "late prepare erased retained reason"
ok "late P0 resume cannot erase retained cleanup evidence"

# Simulated final git-remove refusal must also flip the durable local state.
rm -f "$wt/untracked.txt"
(cd "$wt" && bash scripts/state.sh transition 9 eta P8 running >/dev/null)
(cd "$wt" && bash scripts/state.sh set 9 eta .worktree.cleanup_status '"removed"' >/dev/null)
(cd "$wt" && bash scripts/state.sh set 9 eta .worktree.cleanup_reason '"removed after final CI, upstream-head, and clean-tree verification"' >/dev/null)
(cd "$wt" && bash scripts/state.sh transition 9 eta P8 done >/dev/null)
if [ -n "$(git -C "$wt" status --porcelain)" ]; then
  git -C "$wt" add specs/PROJ-9-eta/state.json
  git -C "$wt" commit -qm "reseal cleanup"
  git -C "$wt" push -q
fi
head="$(git -C "$wt" rev-parse HEAD)"
real_git="$(command -v git)"
fail_bin="$TMP_ROOT/fail-bin"
mkdir -p "$fail_bin"
printf '#!/usr/bin/env bash\nif [ "$1" = -C ] && [ "$3" = worktree ] && [ "$4" = remove ]; then exit 1; fi\nexec "$REAL_GIT" "$@"\n' >"$fail_bin/git"
chmod +x "$fail_bin/git"
if (cd "$repo" && PATH="$fail_bin:$PATH" REAL_GIT="$real_git" "$HELPER" cleanup 9 eta --ci-verified-head "$head" >/dev/null 2>&1); then fail "simulated git remove failure succeeded"; fi
[ "$(jq -r .worktree.cleanup_status "$wt/specs/PROJ-9-eta/state.json")" = retained ] || fail "remove failure did not retain state"
jq -e '.worktree.cleanup_reason | startswith("git refused to remove")' "$wt/specs/PROJ-9-eta/state.json" >/dev/null || fail "remove failure reason missing"
ok "git worktree remove failure falls back to retained state"

# P0 runner integration: the writer creates/seals the worktree, then the
# runner re-execs exactly once in that path. A forged guard in the control
# checkout is rejected instead of recursing.
repo="$TMP_ROOT/runner/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 12 runner absent
runner_bin="$TMP_ROOT/runner-bin"
mkdir -p "$runner_bin"
printf '#!/usr/bin/env bash\nif [ "${1:-}" = login ] && [ "${2:-}" = status ]; then exit 0; fi\nexit 0\n' >"$runner_bin/codex"
printf '#!/usr/bin/env bash\nset -euo pipefail\nwt="$(cd "$RUNNER_TEST_CONTROL" && "$RUNNER_TEST_HELPER" prepare "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME")"\ncp "$RUNNER_TEST_HELPER" "$wt/scripts/worktree.sh"\ncp "$RUNNER_TEST_VALIDATOR" "$wt/scripts/validate-wave-plan.mjs"\nchmod +x "$wt/scripts/worktree.sh" "$wt/scripts/validate-wave-plan.mjs"\n(cd "$wt" && bash scripts/state.sh transition "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME" P0 running >/dev/null)\n(cd "$wt" && bash scripts/state.sh transition "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME" P0 done >/dev/null)\ngit -C "$wt" add -A\ngit -C "$wt" commit -qm "seal P0"\n' >"$runner_bin/claude"
chmod +x "$runner_bin/codex" "$runner_bin/claude"
runner_out="$TMP_ROOT/runner.out"
(cd "$repo" && \
  PATH="$runner_bin:$PATH" \
  RUNNER_TEST_CONTROL="$repo" \
  RUNNER_TEST_HELPER="$HELPER" \
  RUNNER_TEST_VALIDATOR="$ROOT/codex/skills/4b_setup/scripts/validate-wave-plan.mjs" \
  "$ROOT/runner/run-phase.sh" P0 12 runner --timeout 30 >"$runner_out" 2>&1)
[ "$(grep -c 're-entering persistent PROJ worktree exactly once' "$runner_out")" -eq 1 ] || { cat "$runner_out" >&2; fail "runner did not re-exec exactly once"; }
wt="$TMP_ROOT/runner/control-proj12"
[ "$(jq -r '.phase + ":" + .status' "$wt/specs/PROJ-12-runner/state.json")" = P0:done ] || fail "runner worktree state is not P0:done"
if (cd "$repo" && SKILLCHAIN_WORKTREE_REEXEC=1 "$ROOT/runner/run-phase.sh" P0 12 runner >"$TMP_ROOT/guard.out" 2>&1); then
  fail "forged re-exec guard in control checkout was accepted"
fi
grep -F "re-exec guard" "$TMP_ROOT/guard.out" >/dev/null || fail "guard refusal was not explicit"
ok "runner re-enters the P0 worktree exactly once and rejects guard recursion/path mismatch"

restart_out="$TMP_ROOT/runner-restart.out"
(cd "$repo" && \
  PATH="$runner_bin:$PATH" \
  RUNNER_TEST_CONTROL="$repo" \
  RUNNER_TEST_HELPER="$HELPER" \
  RUNNER_TEST_VALIDATOR="$ROOT/codex/skills/4b_setup/scripts/validate-wave-plan.mjs" \
  "$ROOT/runner/run-phase.sh" P0 12 runner --timeout 30 >"$restart_out" 2>&1)
grep -F "registered PROJ worktree is already P0:done before runner restart" "$restart_out" >/dev/null || { cat "$restart_out" >&2; fail "P0 crash-window restart launched another writer"; }
ok "runner restart discovers an already sealed P0 target before spawning"

repo="$TMP_ROOT/runner-auto/control"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 27 omega absent
auto_bin="$TMP_ROOT/runner-auto-bin"
mkdir -p "$auto_bin"
printf '#!/usr/bin/env bash\nif [ "${1:-}" = login ] && [ "${2:-}" = status ]; then exit 0; fi\nexit 0\n' >"$auto_bin/codex"
printf '#!/usr/bin/env bash\nset -euo pipefail\nif [ "$(realpath -m "$PWD")" = "$(realpath -m "$RUNNER_TEST_CONTROL")" ]; then\n  wt="$(cd "$RUNNER_TEST_CONTROL" && "$RUNNER_TEST_HELPER" prepare "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME")"\n  cp "$RUNNER_TEST_HELPER" "$wt/scripts/worktree.sh"\n  cp "$RUNNER_TEST_VALIDATOR" "$wt/scripts/validate-wave-plan.mjs"\n  printf "#!/usr/bin/env bash\\nexit 0\\n" >"$wt/scripts/quality-gate-proof.sh"\n  chmod +x "$wt/scripts/worktree.sh" "$wt/scripts/validate-wave-plan.mjs" "$wt/scripts/quality-gate-proof.sh"\n  (cd "$wt" && bash scripts/state.sh transition "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME" P0 running >/dev/null)\n  (cd "$wt" && bash scripts/state.sh transition "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME" P0 done >/dev/null)\n  git -C "$wt" add -A && git -C "$wt" commit -qm "seal P0"\n  exit 0\nfi\nphase="$(bash scripts/state.sh get "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME" .phase)"\nif [ "$phase" = P0 ]; then\n  printf "%%s\\n" "$PWD" >"$RUNNER_TEST_P5_PWD"\n  bash scripts/state.sh transition "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME" P5 running >/dev/null\n  bash scripts/state.sh transition "$SKILLCHAIN_PROJ" "$SKILLCHAIN_THEME" P5 done >/dev/null\n  git add -A && git commit -qm "seal P5"\n  exit 0\nfi\nexit 42\n' >"$auto_bin/claude"
chmod +x "$auto_bin/codex" "$auto_bin/claude"
set +e
(cd "$repo" && \
  PATH="$auto_bin:$PATH" \
  RUNNER_TEST_CONTROL="$repo" \
  RUNNER_TEST_HELPER="$HELPER" \
  RUNNER_TEST_VALIDATOR="$ROOT/codex/skills/4b_setup/scripts/validate-wave-plan.mjs" \
  RUNNER_TEST_P5_PWD="$TMP_ROOT/p5-pwd" \
  "$ROOT/runner/run-phase.sh" auto 27 omega --timeout 30 >"$TMP_ROOT/runner-auto.out" 2>&1)
auto_rc=$?
set -e
[ "$auto_rc" -eq 1 ] || { cat "$TMP_ROOT/runner-auto.out" >&2; fail "runner auto fixture should stop deliberately at P6"; }
p5_actual="$(cat "$TMP_ROOT/p5-pwd" 2>/dev/null || echo missing)"
[ "$p5_actual" = "$TMP_ROOT/runner-auto/control-proj27" ] || { cat "$TMP_ROOT/runner-auto.out" >&2; fail "P5 did not launch in the persistent worktree (actual=$p5_actual expected=$TMP_ROOT/runner-auto/control-proj27)"; }
[ "$(grep -c 're-entering persistent PROJ worktree exactly once' "$TMP_ROOT/runner-auto.out")" -eq 1 ] || fail "auto runner re-exec count was not one"
ok "runner launches the following P5 phase inside the re-entered worktree"

set +e
(cd "$repo" && \
  PATH="$auto_bin:$PATH" \
  RUNNER_TEST_CONTROL="$repo" \
  RUNNER_TEST_HELPER="$HELPER" \
  RUNNER_TEST_VALIDATOR="$ROOT/codex/skills/4b_setup/scripts/validate-wave-plan.mjs" \
  RUNNER_TEST_P5_PWD="$TMP_ROOT/p5-pwd" \
  "$ROOT/runner/run-phase.sh" auto 27 omega --timeout 30 >"$TMP_ROOT/runner-advanced-restart.out" 2>&1)
advanced_rc=$?
set -e
[ "$advanced_rc" -eq 1 ] || fail "advanced restart fixture should stop deliberately in P6"
grep -E "registered PROJ worktree is already P[5-8]:" "$TMP_ROOT/runner-advanced-restart.out" >/dev/null || { cat "$TMP_ROOT/runner-advanced-restart.out" >&2; fail "advanced control-checkout restart relaunched P0"; }
ok "auto restart re-enters an advanced PROJ lifecycle without relaunching P0"

for copy in \
  "$ROOT/claude/skills/4b_setup/scripts/worktree.sh" \
  "$ROOT/codex/skills/8_delivery/scripts/worktree.sh" \
  "$ROOT/claude/skills/8_delivery/scripts/worktree.sh"
do
  cmp "$HELPER" "$copy" || fail "worktree helper copies differ"
done
ok "all setup/delivery provider copies of worktree.sh are byte-identical"

PREFLIGHT="$ROOT/codex/skills/4b_setup/scripts/preflight.sh"
grep -F 'git gh claude node jq coderabbit realpath flock unlink' "$PREFLIGHT" >/dev/null || fail "preflight hard-tool list lacks worktree lifecycle tools"
jq -e '[.waves[]?.frontend_routes[]?, .frontend.routes[]?] | length > 0' "$PLAN_FIXTURES/config-protected-e2e-valid.json" >/dev/null || fail "structured frontend routes were not detected"
grep -F '[.waves[]?.frontend_routes[]?, .frontend.routes[]?] | length > 0' "$PREFLIGHT" >/dev/null || fail "preflight does not use structured frontend detection"
cmp "$PREFLIGHT" "$ROOT/claude/skills/4b_setup/scripts/preflight.sh" || fail "preflight provider copies differ"
ok "preflight hard-checks worktree tools and detects structured frontend routes"

grep -F 'join(here, "run-phase.sh")' "$ROOT/runner/render-report.mjs" >/dev/null || fail "report resume command does not resolve the actual runner"
if grep -F 'git -C "${s.worktree.control_path}" worktree remove' "$ROOT/runner/render-report.mjs" >/dev/null; then fail "report still recommends raw worktree removal"; fi
ok "reports render a target-cwd P8 resume through the actual runner path"

CI_POLL="$ROOT/codex/skills/8_delivery/scripts/ci-poll.sh"
ci_bin="$TMP_ROOT/ci-bin"
mkdir -p "$ci_bin"
printf '#!/usr/bin/env bash\nset -euo pipefail\nif [ "$1 $2" = "pr view" ]; then\n  count=0; [ ! -f "$GH_PR_COUNT" ] || count="$(cat "$GH_PR_COUNT")"\n  count=$((count + 1)); printf "%%s" "$count" >"$GH_PR_COUNT"\n  if [ "$count" -eq 1 ]; then printf "%%s\\n" "$GH_HEAD_FIRST"; else printf "%%s\\n" "$GH_HEAD_SECOND"; fi\nelif [ "$1 $2" = "run list" ]; then\n  cat "$GH_RUNS_FILE"\nelif [ "$1 $2" = "pr checks" ]; then\n  exit 0\nelse\n  exit 9\nfi\n' >"$ci_bin/gh"
chmod +x "$ci_bin/gh"
jq -cn '[{databaseId:1,status:"completed",conclusion:"success",name:"ci"}]' >"$TMP_ROOT/gh-runs.json"
head_a=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
head_b=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
if PATH="$ci_bin:$PATH" GH_RUNS_FILE="$TMP_ROOT/gh-runs.json" GH_PR_COUNT="$TMP_ROOT/gh-count-1" GH_HEAD_FIRST="$head_b" GH_HEAD_SECOND="$head_b" bash "$CI_POLL" 1 1 "$head_a" >/dev/null 2>&1; then fail "ci-poll accepted a pre-poll expected-head mismatch"; fi
if PATH="$ci_bin:$PATH" GH_RUNS_FILE="$TMP_ROOT/gh-runs.json" GH_PR_COUNT="$TMP_ROOT/gh-count-2" GH_HEAD_FIRST="$head_a" GH_HEAD_SECOND="$head_b" bash "$CI_POLL" 1 1 "$head_a" >/dev/null 2>&1; then fail "ci-poll accepted a PR-head change during polling"; fi
cmp "$CI_POLL" "$ROOT/claude/skills/8_delivery/scripts/ci-poll.sh" || fail "ci-poll provider copies differ"
ok "final CI polling binds and rechecks the exact expected PR head"

# P8 crash-window resume: durable P8:done+removed with a live registered path
# must not be skipped by either run_one_phase or the outer auto loop.
repo="$TMP_ROOT/p8-resume/control"
remote="$TMP_ROOT/p8-resume/remote.git"
mkdir -p "$(dirname "$repo")"
init_repo "$repo" 28 psi absent "$remote"
wt="$(cd "$repo" && "$HELPER" prepare 28 psi)"
cp "$HELPER" "$wt/scripts/worktree.sh"
cp "$CI_POLL" "$wt/scripts/ci-poll.sh"
chmod +x "$wt/scripts/worktree.sh" "$wt/scripts/ci-poll.sh"
advance_to_p8_done "$wt" 28 psi
head="$(git -C "$wt" rev-parse HEAD)"
resume_out="$TMP_ROOT/p8-resume.out"
set +e
(cd "$wt" && \
  PATH="$ci_bin:$PATH" \
  GH_RUNS_FILE="$TMP_ROOT/gh-runs.json" \
  GH_PR_COUNT="$TMP_ROOT/gh-count-resume" GH_HEAD_FIRST="$head" GH_HEAD_SECOND="$head" \
  "$ROOT/runner/run-phase.sh" auto 28 psi --timeout 30 >"$resume_out" 2>&1)
resume_rc=$?
set -e
[ "$resume_rc" -eq 0 ] || { cat "$resume_out" >&2; fail "post-seal P8 resume failed with $resume_rc"; }
[ ! -e "$wt" ] || { cat "$resume_out" >&2; fail "auto skipped unfinished post-seal P8 cleanup"; }
grep -F "P8 seal already exists but worktree cleanup is unfinished" "$resume_out" >/dev/null || fail "P8 finalization resume was not explicit"
ok "auto resumes final CI/cleanup after a post-seal P8 crash"

echo "PASS: $PASS worktree behavior groups"
