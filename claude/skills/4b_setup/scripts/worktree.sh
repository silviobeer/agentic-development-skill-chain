#!/usr/bin/env bash
# worktree.sh — persistent PROJ worktree lifecycle + shared-resource lock.
#
# Usage:
#   worktree.sh prepare <proj-x> <theme>
#   worktree.sh locate <proj-x>
#   worktree.sh retain <proj-x> <theme> <reason>
#   worktree.sh cleanup <proj-x> <theme> --ci-verified-head <sha>
#   worktree.sh with-shared-lock [--timeout <seconds>] -- <command...>
#
# `prepare` must run from the clean control checkout at the committed CP1
# HEAD. It creates or resumes the persistent sibling worktree, links only an
# ignored .env.local, installs dependencies from a lockfile, and records the
# topology through state.sh. `cleanup` is deliberately conservative: the
# final CI head, upstream head, branch, registration, and clean tree must all
# agree before the exact registered worktree is removed. The PROJ branch is
# never deleted.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  worktree.sh prepare <proj-x> <theme>
  worktree.sh locate <proj-x>
  worktree.sh retain <proj-x> <theme> <reason>
  worktree.sh cleanup <proj-x> <theme> --ci-verified-head <sha>
  worktree.sh with-shared-lock [--timeout <seconds>] -- <command...>
Environment:
  SKILLCHAIN_WORKTREE_ROOT          parent directory for persistent worktrees
  SKILLCHAIN_SHARED_RESOURCE_LOCK  shared database/auth lock file override
  SKILLCHAIN_DEV_PORT              explicit recorded dev port override
Exit: 0 ok · 1 safety/precondition failure · 73 lock timeout · 64 usage
EOF
  exit 64
}

die() { echo "worktree.sh: $*" >&2; exit 1; }

for required_command in git jq node realpath flock awk sed unlink; do
  command -v "$required_command" >/dev/null 2>&1 \
    || die "required command '$required_command' is missing"
done

canonical_path() {
  realpath -m -- "$1"
}

git_common_dir() {
  local raw top
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git worktree"
  raw="$(git rev-parse --git-common-dir)"
  case "$raw" in
    /*) canonical_path "$raw" ;;
    *) canonical_path "$top/$raw" ;;
  esac
}

registered_path_for_branch() {
  local branch="$1"
  git worktree list --porcelain | awk -v want="refs/heads/$branch" '
    $1 == "worktree" { path = substr($0, 10) }
    $1 == "branch" && $2 == want { print path; exit }
  '
}

registered_branch_for_path() {
  local target="$1"
  git worktree list --porcelain | awk -v want="$target" '
    $1 == "worktree" { path = substr($0, 10) }
    $1 == "branch" && path == want { sub(/^refs\/heads\//, "", $2); print $2; exit }
  '
}

state_recorded_worktree() { # proj theme — unique registered path carrying its own matching state metadata
  local proj="$1" theme="$2" path state recorded candidates=()
  while IFS= read -r path; do
    path="$(canonical_path "$path")"
    state="$path/specs/PROJ-${proj}-${theme}/state.json"
    [ -f "$state" ] || continue
    [ "$(jq -r '.proj // empty' "$state")" = "PROJ-${proj}" ] || continue
    [ "$(jq -r '.theme // empty' "$state")" = "$theme" ] || continue
    recorded="$(jq -r '.worktree.path // empty' "$state")"
    [ -n "$recorded" ] && [ "$(canonical_path "$recorded")" = "$path" ] || continue
    candidates+=("$path")
  done < <(git worktree list --porcelain | awk '$1 == "worktree" { print substr($0, 10) }')
  [ "${#candidates[@]}" -eq 1 ] || return 1
  echo "${candidates[0]}"
}

state_helper_for() {
  local worktree="$1" self_dir
  if [ -x "$worktree/scripts/state.sh" ]; then
    canonical_path "$worktree/scripts/state.sh"
    return
  fi
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -x "$self_dir/state.sh" ] || die "state.sh not found in the worktree or beside worktree.sh"
  echo "$self_dir/state.sh"
}

set_worktree_state() {
  local worktree="$1" proj="$2" theme="$3" path_expr="$4" value="$5" state_sh
  state_sh="$(state_helper_for "$worktree")"
  (cd "$worktree" && "$state_sh" set "$proj" "$theme" "$path_expr" "$value" >/dev/null)
}

detect_dev_port() {
  local worktree="$1" proj="$2" theme="$3" config url port
  if [ -n "${SKILLCHAIN_DEV_PORT:-}" ]; then
    case "$SKILLCHAIN_DEV_PORT" in ''|*[!0-9]*) die "SKILLCHAIN_DEV_PORT must be an integer" ;; esac
    echo "$SKILLCHAIN_DEV_PORT"
    return
  fi
  config="$worktree/specs/PROJ-${proj}-${theme}/3-4_plan/wave-gate-config.json"
  [ -f "$config" ] || { echo null; return; }
  url="$(jq -r '.frontend.dev_url // empty' "$config" 2>/dev/null || true)"
  [ -n "$url" ] || { echo null; return; }
  port="$(sed -nE 's#^[A-Za-z][A-Za-z0-9+.-]*://[^/:]+:([0-9]+)(/.*)?$#\1#p' <<<"$url")"
  if [ -z "$port" ]; then
    case "$url" in https://*) port=443 ;; http://*) port=80 ;; *) echo null; return ;; esac
  fi
  case "$port" in ''|*[!0-9]*) echo null ;; *) echo "$port" ;; esac
}

dependency_kind() {
  local root="$1" found=()
  [ -f "$root/pnpm-lock.yaml" ] && found+=(pnpm)
  { [ -f "$root/package-lock.json" ] || [ -f "$root/npm-shrinkwrap.json" ]; } && found+=(npm)
  [ -f "$root/yarn.lock" ] && found+=(yarn)
  { [ -f "$root/bun.lock" ] || [ -f "$root/bun.lockb" ]; } && found+=(bun)
  [ "${#found[@]}" -le 1 ] || die "multiple JavaScript lockfiles found (${found[*]}); cannot choose a reproducible installer"
  if [ "${#found[@]}" -eq 0 ]; then
    [ ! -f "$root/package.json" ] || die "package.json exists without a supported lockfile; refusing a non-reproducible dependency install"
    echo none
  else
    echo "${found[0]}"
  fi
}

install_dependencies() {
  local worktree="$1" kind="$2"
  [ ! -L "$worktree/node_modules" ] || die "$worktree/node_modules is a symlink; dependencies must stay isolated"
  case "$kind" in
    none) echo not_applicable ;;
    npm) (cd "$worktree" && npm ci >&2) || return $?; echo installed ;;
    pnpm) (cd "$worktree" && corepack pnpm install --frozen-lockfile >&2) || return $?; echo installed ;;
    yarn) (cd "$worktree" && corepack yarn install --immutable >&2) || return $?; echo installed ;;
    bun) (cd "$worktree" && bun install --frozen-lockfile >&2) || return $?; echo installed ;;
    *) die "internal error: unsupported dependency kind '$kind'" ;;
  esac
}

validate_env_source() {
  local control="$1"
  if [ -e "$control/.env.local" ] || [ -L "$control/.env.local" ]; then
    git -C "$control" check-ignore -q -- .env.local \
      || die "$control/.env.local exists but is not ignored by Git"
    echo linked
  elif [ -e "$control/.env.local.example" ] || [ -L "$control/.env.local.example" ]; then
    die "$control/.env.local is missing while .env.local.example exists; create the ignored local file before P0"
  else
    echo not_present
  fi
}

validate_wave_plan() {
  local control="$1" proj="$2" theme="$3" plan_dir self_dir validator
  plan_dir="$control/specs/PROJ-${proj}-${theme}/3-4_plan"
  [ -d "$plan_dir" ] || plan_dir="$control/specs/PROJ-${proj}-${theme}/6_plan"
  [ -d "$plan_dir" ] || die "wave plan directory is missing (expected 3-4_plan/ or legacy 6_plan/)"
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  validator="$self_dir/validate-wave-plan.mjs"
  [ -f "$validator" ] || die "validate-wave-plan.mjs is missing beside the setup worktree helper"
  node "$validator" "$plan_dir" || die "wave plan consistency validation failed"
}

link_env() {
  local control="$1" worktree="$2" status="$3" source existing
  if [ "$status" = not_present ]; then
    [ ! -e "$worktree/.env.local" ] && [ ! -L "$worktree/.env.local" ] \
      || die "$worktree/.env.local exists but the control checkout has no .env.local; refusing stale or unmanaged env state"
    return 0
  fi
  source="$control/.env.local"
  if [ -L "$worktree/.env.local" ]; then
    existing="$(readlink "$worktree/.env.local")"
    [ "$existing" = "$source" ] || die "$worktree/.env.local points to '$existing', expected '$source'"
  elif [ -e "$worktree/.env.local" ]; then
    die "$worktree/.env.local exists and is not the managed symlink"
  else
    ln -s "$source" "$worktree/.env.local"
  fi
}

hide_env_during_install() {
  local control="$1" worktree="$2" status="$3" existing
  if [ -L "$worktree/.env.local" ]; then
    existing="$(readlink "$worktree/.env.local")"
    [ "$status" = linked ] && [ "$existing" = "$control/.env.local" ] \
      || die "$worktree/.env.local is stale or unmanaged; refusing to expose it to dependency lifecycle scripts"
    unlink "$worktree/.env.local"
    echo hidden
  elif [ -e "$worktree/.env.local" ]; then
    die "$worktree/.env.local exists and is not the managed symlink"
  else
    echo absent
  fi
}

prepare() {
  [ $# -eq 2 ] || usage
  local proj="$1" theme="$2" branch control control_parent repo_name root target
  local registered target_branch env_status dep_kind dep_status dep_rc env_hidden base_sha tag tag_sha dev_port metadata state target_lifecycle
  branch="proj/PROJ-${proj}"
  control="$(canonical_path "$(git rev-parse --show-toplevel 2>/dev/null)")" || die "not inside the control checkout"
  [ "$(canonical_path "$PWD")" = "$control" ] || die "prepare must run from the control checkout root: $control"
  [ -z "$(git -C "$control" status --porcelain)" ] || die "control checkout has uncommitted changes; commit or remove them before P0"
  base_sha="$(git -C "$control" rev-parse HEAD)"
  state="$control/specs/PROJ-${proj}-${theme}/state.json"
  [ -f "$state" ] || die "$state is missing; P0 requires a committed CP1 approval"
  [ "$(jq -r '.phase + ":" + .status' "$state" 2>/dev/null || true)" = CP1:approved ] \
    || die "state at committed control HEAD is not CP1:approved"
  validate_wave_plan "$control" "$proj" "$theme" >&2
  env_status="$(validate_env_source "$control")"
  dep_kind="$(dependency_kind "$control")"

  control_parent="$(dirname "$control")"
  repo_name="$(basename "$control")"
  root="${SKILLCHAIN_WORKTREE_ROOT:-$control_parent}"
  root="$(canonical_path "$root")"
  mkdir -p "$root"
  target="$(canonical_path "$root/${repo_name}-proj${proj}")"
  [ "$target" != "$control" ] || die "resolved worktree path equals the control checkout"

  # Validate the immutable base tag before creating a branch/worktree so a
  # conflict cannot leave a half-created topology behind.
  tag="proj-PROJ-${proj}-base"
  if git -C "$control" show-ref --verify --quiet "refs/tags/$tag"; then
    tag_sha="$(git -C "$control" rev-list -n 1 "$tag")"
    [ "$tag_sha" = "$base_sha" ] || die "tag $tag already points to $tag_sha, expected $base_sha"
  fi

  registered="$(registered_path_for_branch "$branch")"
  if [ -n "$registered" ]; then
    registered="$(canonical_path "$registered")"
    [ "$registered" = "$target" ] || die "$branch is already registered at $registered (expected $target)"
    [ -d "$target" ] || die "$branch registration points to missing path $target; run git worktree repair explicitly"
    state="$target/specs/PROJ-${proj}-${theme}/state.json"
    target_lifecycle="$(jq -r '.phase + ":" + .status' "$state" 2>/dev/null || true)"
    case "$target_lifecycle" in
      CP1:approved|P0:running|P0:blocked|P0:done) : ;;
      *) die "registered worktree already advanced to ${target_lifecycle:-unknown}; P0 prepare may not reset its lifecycle or cleanup evidence" ;;
    esac
  else
    if [ -e "$target" ] || [ -L "$target" ]; then
      target_branch="$(registered_branch_for_path "$target")"
      [ -z "$target_branch" ] || die "$target is already registered to $target_branch"
      die "target path $target already exists but is not the registered $branch worktree"
    fi
    if git -C "$control" show-ref --verify --quiet "refs/heads/$branch"; then
      [ "$(git -C "$control" rev-parse "$branch")" = "$base_sha" ] \
        || die "existing $branch is not at the committed CP1 HEAD $base_sha"
      git -C "$control" worktree add "$target" "$branch" >&2
    else
      git -C "$control" worktree add -b "$branch" "$target" "$base_sha" >&2
    fi
  fi

  if ! git -C "$control" show-ref --verify --quiet "refs/tags/$tag"; then
    git -C "$control" tag "$tag" "$base_sha"
  fi

  env_hidden="$(hide_env_during_install "$control" "$target" "$env_status")"
  set +e
  dep_status="$(install_dependencies "$target" "$dep_kind")"
  dep_rc=$?
  set -e
  if [ "$dep_rc" -ne 0 ]; then
    if [ "$env_hidden" = hidden ]; then
      ln -s "$control/.env.local" "$target/.env.local" \
        || die "dependency install failed and the validated env symlink could not be restored"
    fi
    die "reproducible dependency install failed with exit $dep_rc; managed env state restored"
  fi
  # Install before linking secrets: lifecycle/postinstall output can never
  # observe or print .env.local during dependency setup.
  link_env "$control" "$target" "$env_status"
  dev_port="$(detect_dev_port "$target" "$proj" "$theme")"
  metadata="$(jq -cn \
    --arg control "$control" --arg path "$target" --arg branch "$branch" \
    --arg env "$env_status" --arg dep "$dep_status" --argjson port "$dev_port" \
    '{control_path:$control,path:$path,branch:$branch,env_link_status:$env,database_mode:"shared",dev_port:$port,dependency_install:$dep,cleanup_status:"pending",cleanup_reason:null}')"
  set_worktree_state "$target" "$proj" "$theme" .worktree "$metadata"
  set_worktree_state "$target" "$proj" "$theme" .base_sha "\"$base_sha\""
  set_worktree_state "$target" "$proj" "$theme" .branch "\"$branch\""
  echo "$target"
}

locate() {
  [ $# -eq 1 ] || usage
  local branch path
  branch="proj/PROJ-$1"
  path="$(registered_path_for_branch "$branch")"
  [ -n "$path" ] || die "$branch has no registered worktree"
  canonical_path "$path"
}

retain_at() {
  local worktree="$1" proj="$2" theme="$3" reason="$4" state_sh lifecycle
  # Apply the two values separately through the sole state writer. A retained
  # worktree remains intentionally dirty until delivery is resumed and sealed.
  set_worktree_state "$worktree" "$proj" "$theme" .worktree.cleanup_status '"retained"'
  set_worktree_state "$worktree" "$proj" "$theme" .worktree.cleanup_reason "$(jq -cn --arg r "$reason" '$r')"
  state_sh="$(state_helper_for "$worktree")"
  lifecycle="$(cd "$worktree" && "$state_sh" get "$proj" "$theme" '.phase + ":" + .status')"
  if [ "$lifecycle" = P8:done ]; then
    (cd "$worktree" && "$state_sh" transition "$proj" "$theme" P8 blocked >/dev/null)
  fi
  echo "worktree retained: $reason" >&2
  printf 'safe next action: resume P8 delivery for PROJ-%s/%s, reseal, push, and re-poll CI for the exact new HEAD before guarded cleanup\n' \
    "$proj" "$theme" >&2
}

retain() {
  [ $# -eq 3 ] || usage
  local proj="$1" theme="$2" reason="$3" worktree
  worktree="$(registered_path_for_branch "proj/PROJ-${proj}")"
  [ -n "$worktree" ] || worktree="$(state_recorded_worktree "$proj" "$theme" || true)"
  [ -n "$worktree" ] || die "cannot identify one safe registered worktree whose state can be marked retained"
  retain_at "$(canonical_path "$worktree")" "$proj" "$theme" "$reason"
}

cleanup() {
  [ $# -eq 4 ] && [ "$3" = "--ci-verified-head" ] || usage
  local proj="$1" theme="$2" ci_head="$4" branch worktree state control head upstream upstream_ref remote merge_ref remote_branch
  branch="proj/PROJ-${proj}"
  case "$ci_head" in ''|*[!0-9a-fA-F]*) die "--ci-verified-head must be a full commit SHA" ;; esac
  [ "${#ci_head}" -ge 40 ] || die "--ci-verified-head must be a full commit SHA"
  worktree="$(registered_path_for_branch "$branch")"
  if [ -z "$worktree" ]; then
    worktree="$(state_recorded_worktree "$proj" "$theme" || true)"
    if [ -n "$worktree" ]; then
      worktree="$(canonical_path "$worktree")"
      retain_at "$worktree" "$proj" "$theme" "proj branch is not registered to its recorded worktree (detached or conflicting registration)"
      return 1
    fi
    die "$branch has no registered worktree and no unique state-recorded worktree can be identified safely"
  fi
  worktree="$(canonical_path "$worktree")"
  state="$worktree/specs/PROJ-${proj}-${theme}/state.json"
  [ -f "$state" ] || die "$state missing"
  control="$(jq -r '.worktree.control_path // empty' "$state")"
  [ -n "$control" ] && [ -d "$control" ] || { retain "$proj" "$theme" "control checkout recorded in state is missing"; return 1; }
  control="$(canonical_path "$control")"
  [ "$(jq -r '.worktree.path // empty' "$state")" = "$worktree" ] \
    || { retain "$proj" "$theme" "registered path does not match state.worktree.path"; return 1; }
  [ "$(jq -r '.worktree.branch // empty' "$state")" = "$branch" ] \
    || { retain "$proj" "$theme" "registered branch does not match state.worktree.branch"; return 1; }
  [ "$(git -C "$worktree" branch --show-current)" = "$branch" ] \
    || { retain "$proj" "$theme" "worktree is not on $branch"; return 1; }
  [ "$(jq -r '.phase + ":" + .status' "$state")" = "P8:done" ] \
    || { retain "$proj" "$theme" "state is not P8:done"; return 1; }
  [ "$(jq -r '.pr.ci // empty' "$state")" = green ] \
    || { retain "$proj" "$theme" "state does not record final CI as green"; return 1; }
  [ "$(jq -r '.worktree.cleanup_status // empty' "$state")" = removed ] \
    || { retain "$proj" "$theme" "cleanup was not sealed as removed in the final P8 commit"; return 1; }
  head="$(git -C "$worktree" rev-parse HEAD)"
  [ "$head" = "$ci_head" ] \
    || { retain "$proj" "$theme" "final CI verified $ci_head but worktree HEAD is $head"; return 1; }
  upstream_ref="$(git -C "$worktree" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  remote="$(git -C "$worktree" config --get "branch.${branch}.remote" 2>/dev/null || true)"
  merge_ref="$(git -C "$worktree" config --get "branch.${branch}.merge" 2>/dev/null || true)"
  [ -n "$upstream_ref" ] && [ -n "$remote" ] && [ "$remote" != . ] \
    && [ -n "$merge_ref" ] && [[ "$upstream_ref" == refs/remotes/* ]] \
    || { retain "$proj" "$theme" "PROJ branch has no remote-tracking upstream"; return 1; }
  remote_branch="${merge_ref#refs/heads/}"
  [ "$remote_branch" != "$merge_ref" ] \
    || { retain "$proj" "$theme" "upstream merge ref is not a remote branch"; return 1; }
  if ! git -C "$worktree" fetch --quiet "$remote" "$merge_ref"; then
    retain "$proj" "$theme" "could not fetch authoritative upstream $remote/$remote_branch"
    return 1
  fi
  # An explicit-ref fetch updates FETCH_HEAD even when the local remote-
  # tracking ref is stale or the fetch refspec does not update it. Compare
  # the authoritative fetched commit, not @{upstream}'s cached local value.
  upstream="$(git -C "$worktree" rev-parse FETCH_HEAD 2>/dev/null || true)"
  [ -n "$upstream" ] \
    || { retain "$proj" "$theme" "PROJ branch has no upstream"; return 1; }
  [ "$upstream" = "$head" ] \
    || { retain "$proj" "$theme" "upstream $upstream does not match local HEAD $head"; return 1; }
  if [ -n "$(git -C "$worktree" status --porcelain)" ]; then
    retain "$proj" "$theme" "worktree has tracked or untracked changes"
    return 1
  fi
  local ignored entry unexpected=()
  ignored="$(git -C "$worktree" ls-files --others --ignored --exclude-standard)"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$entry" in
      node_modules/*|*/node_modules/*) : ;;
      "specs/PROJ-${proj}-${theme}/.state.lock") : ;;
      .env.local)
        [ "$(jq -r '.worktree.env_link_status' "$state")" = linked ] \
          && [ -L "$worktree/.env.local" ] \
          && [ "$(readlink "$worktree/.env.local")" = "$control/.env.local" ] \
          || unexpected+=("$entry")
        ;;
      *) unexpected+=("$entry") ;;
    esac
  done <<<"$ignored"
  if [ "${#unexpected[@]}" -gt 0 ]; then
    retain "$proj" "$theme" "worktree contains unexpected ignored payloads: ${unexpected[*]}"
    return 1
  fi

  # --force is necessary for reproducible, ignored dependencies and the
  # managed ignored .env.local link. Every safety predicate above resolves an
  # exact registered path first; only that path is removed, never the branch.
  if ! git -C "$control" worktree remove --force "$worktree"; then
    if [ -d "$worktree" ] && [ -n "$(registered_path_for_branch "$branch")" ]; then
      retain "$proj" "$theme" "git refused to remove the verified worktree $worktree"
    else
      echo "worktree.sh: removal failed after Git changed the registration; inspect 'git worktree list' before any manual cleanup" >&2
    fi
    return 1
  fi
  echo "worktree removed: $worktree (ignored dependencies and managed env symlink were discarded; branch $branch remains)" >&2
}

with_shared_lock() {
  local timeout=600 lock common
  if [ "${1:-}" = "--timeout" ]; then
    timeout="${2:-}"; shift 2
  fi
  [ "${1:-}" = "--" ] || usage
  shift
  [ $# -gt 0 ] || usage
  case "$timeout" in ''|*[!0-9]*) usage ;; esac
  if [ -n "${SKILLCHAIN_SHARED_RESOURCE_LOCK:-}" ]; then
    case "$SKILLCHAIN_SHARED_RESOURCE_LOCK" in
      /*) : ;;
      *) die "SKILLCHAIN_SHARED_RESOURCE_LOCK must be an absolute shared path" ;;
    esac
    lock="$(canonical_path "$SKILLCHAIN_SHARED_RESOURCE_LOCK")"
  else
    common="$(git_common_dir)"
    lock="$common/skillchain-shared-resources.lock"
  fi
  mkdir -p "$(dirname "$lock")"
  exec 8>"$lock" || die "cannot open shared-resource lock $lock"
  if ! flock -w "$timeout" 8; then
    echo "worktree.sh: shared-resource lock timed out after ${timeout}s: $lock" >&2
    exit 73
  fi
  "$@"
}

COMMAND="${1:-}"; [ -n "$COMMAND" ] || usage; shift
case "$COMMAND" in
  prepare) prepare "$@" ;;
  locate) locate "$@" ;;
  retain) retain "$@" ;;
  cleanup) cleanup "$@" ;;
  with-shared-lock) with_shared_lock "$@" ;;
  *) usage ;;
esac
