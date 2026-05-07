#!/usr/bin/env bash
# Merge the execution permissions template into the project's .claude/settings.json.
# Idempotent: re-running adds nothing new if template entries are already present.
# Deny list is additive too — never removes existing deny rules.
#
# Usage: bash scripts/merge-project-settings.sh [--dry-run]
#
# Relies on jq. Exits non-zero if jq is missing, template is missing, or merge fails.

set -euo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

PROJECT_SETTINGS=".claude/settings.json"
TEMPLATE="${CLAUDE_EXEC_TEMPLATE:-$HOME/.claude/skills/5_executing/references/project-settings-template.json}"

command -v jq >/dev/null 2>&1 || { echo "merge-project-settings: jq not installed" >&2; exit 2; }
[[ -f "$TEMPLATE" ]] || { echo "merge-project-settings: template not found at $TEMPLATE" >&2; exit 2; }

mkdir -p "$(dirname "$PROJECT_SETTINGS")"
[[ -f "$PROJECT_SETTINGS" ]] || echo '{}' > "$PROJECT_SETTINGS"

# Strip "_comment" + "$schema" from template, then union allow/deny arrays.
# defaultMode: project wins if explicitly set, otherwise template supplies it.
MERGED=$(jq -s '
  def union_unique: (.[0] // []) + (.[1] // []) | unique;
  (.[0] | del(._comment, ."$schema")) as $tpl
  | .[1] as $proj
  | $proj
    | .permissions.allow = (($proj.permissions.allow // []) + ($tpl.permissions.allow // []) | unique)
    | .permissions.deny  = (($proj.permissions.deny  // []) + ($tpl.permissions.deny  // []) | unique)
    | (if ($proj.permissions.defaultMode // null) == null and ($tpl.permissions.defaultMode // null) != null
       then .permissions.defaultMode = $tpl.permissions.defaultMode
       else . end)
' "$TEMPLATE" "$PROJECT_SETTINGS")

if [[ "$DRY_RUN" == "1" ]]; then
  echo "$MERGED" | jq .
  exit 0
fi

TMP=$(mktemp)
echo "$MERGED" | jq . > "$TMP"
mv "$TMP" "$PROJECT_SETTINGS"
echo "merge-project-settings: .claude/settings.json updated ($(jq '.permissions.allow | length' "$PROJECT_SETTINGS") allow, $(jq '.permissions.deny | length' "$PROJECT_SETTINGS") deny)"
