#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${CODEX_HOME:-$HOME/.codex}/skills"

mkdir -p "$DEST"

# Skills folded into others; a leftover copy would still be discoverable.
for retired in 4a_checkpoint 4b_setup; do
  rm -rf "${DEST:?}/$retired"
done

for skill in "$ROOT"/codex/skills/*; do
  [ -d "$skill" ] || continue
  name="$(basename "$skill")"
  rm -rf "$DEST/$name"
  cp -R "$skill" "$DEST/$name"
done

echo "Installed Codex skills to $DEST"
