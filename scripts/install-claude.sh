#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}/skills"

mkdir -p "$DEST"

# Skills folded into others; a leftover copy would still be discoverable.
for retired in 4a_checkpoint 4b_setup; do
  rm -rf "${DEST:?}/$retired"
done

for skill in "$ROOT"/claude/skills/*; do
  [ -d "$skill" ] || continue
  name="$(basename "$skill")"
  rm -rf "$DEST/$name"
  cp -R "$skill" "$DEST/$name"
done

echo "Installed Claude skills to $DEST"
