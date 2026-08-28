# env-local.sh — load .env.local into the current shell, sourced (not run).
# A persistent worktree is a separate process tree from wherever secrets were
# exported (control checkout's shell, CI, ...), so the ambient env can't be
# relied on for ANY of them here — not just CodeRabbit. .env.local is already
# the one managed secrets file worktree.sh symlinks into every worktree; load
# whatever it has (never overriding an already-set var) instead of hardcoding
# a per-tool fallback for each token a given stack happens to use.
load_env_local() {
  local file="$1" line key value
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in ''|'#'*) continue ;; esac
    key="${line%%=*}"; value="${line#*=}"
    [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    value="${value%\"}"; value="${value#\"}"; value="${value%\'}"; value="${value#\'}"
    [[ -n "${!key:-}" ]] && continue
    export "$key=$value"
  done <"$file"
}
load_env_local .env.local
