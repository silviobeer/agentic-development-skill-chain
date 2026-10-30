#!/usr/bin/env bash
# risk-check.sh — decide the QA profile (fast|full) for a PROJ, deterministically.
#
# Usage: chain check risk <proj-x> <theme> [--base SHA]   (this file: risk-check.sh)
#   Run from the repo root (or the PROJ worktree). --base overrides state.json .base_sha.
# Output: line 1 is `fast` or `full`; every further line is `- <reason>`.
# Exit:   0 a decision was made (read line 1); 64 invalid use; 1 infrastructure error.
#
# `fast` needs the fast-track marker AND no risk signal. Anything unreadable, empty or
# doubtful is `full`: the check only ever narrows QA when it can prove the change is small
# and boring. Signals are matched on added AND removed lines (a deleted auth guard counts) of non-spec,
# non-test, non-Markdown files, on the hunk context (the enclosing function git prints after `@@`) and on the
# file path. Comment lines stay in the scan: `//go:build`, `#if` and `/* */` directives carry behavior. The
# patterns are deliberately broad (a false `full` costs QA time, a false `fast` costs coverage). It is a
# heuristic filter, not a proof: it cannot see a risky change inside a function whose name and path carry no
# signal word.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage() { echo "Usage: risk-check.sh <proj-x> <theme> [--base SHA]" >&2; exit 64; }
[ $# -ge 2 ] || usage
PROJ="${1#PROJ-}"; THEME="$2"; shift 2
BASE_SHA=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || usage; BASE_SHA="$2"; shift 2 ;;
    *) usage ;;
  esac
done

LINES_PER_STORY=150 # a fast-track story is small: more changed lines than this per story is a doubt
FILES_PER_STORY=5

reasons=()
full() { reasons+=("$1"); }
finish() {
  if [ "${#reasons[@]}" -gt 0 ]; then echo full; printf -- '- %s\n' "${reasons[@]}"; else echo fast; echo "- fast-track marker present; no risk signal in $BASE_SHA..HEAD"; fi
  exit 0
}

DIR="specs/PROJ-${PROJ}-${THEME}"
CONCEPT="$DIR/1_concept/PROJ-${PROJ}-concept.md"
if [ ! -r "$CONCEPT" ]; then full "no readable concept at $CONCEPT"; finish; fi
# The marker counts only as its own line of the Handoff Readiness section (formatting characters stripped, optional
# `-`/`+` bullet) whose whole value is fast-track-spec: not anywhere else in the file, not as a prefix like
# fast-track-spec-disabled and not sharing a line with other text (1f dictates two own-line bullets).
awk '/^#+[[:space:]]/ { in_section = ($0 ~ /^#+[[:space:]]+Handoff Readiness[[:space:]]*$/); next } in_section { gsub(/[`*]/, ""); print }' "$CONCEPT" \
  | grep -Eq '^[[:space:]]*([-+][[:space:]]+)?Authored via:[[:space:]]*fast-track-spec[[:space:]]*$' \
  || { full "no 'Authored via: fast-track-spec' marker in the concept's Handoff Readiness (full chain PROJ)"; finish; }

if [ -z "$BASE_SHA" ]; then
  STATE_SH="scripts/state.sh"; [ -f "$STATE_SH" ] || STATE_SH="$SCRIPT_DIR/../../5_executing/scripts/state.sh"
  [ -f "$STATE_SH" ] && [ -f "$DIR/state.json" ] && BASE_SHA="$(bash "$STATE_SH" get "$PROJ" "$THEME" '.base_sha // empty' 2>/dev/null || true)"
fi
[ -n "$BASE_SHA" ] || { full "no base commit (state.json .base_sha missing and no --base)"; finish; }
git rev-parse --verify --quiet "$BASE_SHA^{commit}" >/dev/null || { full "base commit $BASE_SHA is not in this repository"; finish; }
git merge-base --is-ancestor "$BASE_SHA" HEAD 2>/dev/null || { full "base commit $BASE_SHA is not an ancestor of HEAD"; finish; }

# Production code only: specs, tests and Markdown prose never carry the risk (a docs-only diff has nothing to assess
# and reads `full`). Only `.md` counts as prose: MDX components and code files under docs/ are executable and stay scanned.
EXCLUDES=(':(exclude)specs/**' ':(exclude,glob)**/*.md' ':(exclude)**/*.test.*' ':(exclude)**/*.spec.*' ':(exclude)**/__tests__/**' ':(exclude)**/tests/**' ':(exclude)**/test/**' ':(exclude)**/*_test.*' ':(exclude)**/test_*.*')
RANGE="$BASE_SHA..HEAD"
# BASE..HEAD does not see staged, unstaged or untracked work: uncommitted production code cannot be assessed.
dirty="$(git status --porcelain --untracked-files=all -- . "${EXCLUDES[@]}" | wc -l | tr -d ' ')"
[ "$dirty" -eq 0 ] || full "uncommitted production-code changes ($dirty path(s)); commit before the risk check"
DIFF_OPTS=(--no-color --no-ext-diff --no-renames)

# --- size: against the PRD story count (a PRD with no parsable story counts as one) ---
stories=0
if [ -d "$DIR/2_PRDs" ]; then
  stories="$(cat "$DIR/2_PRDs/"*.md 2>/dev/null | grep -cE '^#{2,4}[[:space:]].*US-[0-9]+' || true)"
fi
[ "$stories" -ge 1 ] || stories=1
read -r changed_lines changed_files binary_files < <(git diff "${DIFF_OPTS[@]}" --numstat "$RANGE" -- . "${EXCLUDES[@]}" | awk '{ if ($1 != "-") n += $1 + $2; else b++; f++ } END { print n + 0, f + 0, b + 0 }')
[ "$changed_files" -gt 0 ] || { full "no production-code change in $RANGE; nothing to assess"; finish; }
[ "$binary_files" -eq 0 ] || full "binary file changed ($binary_files): the content cannot be inspected"
[ "$changed_lines" -le $((stories * LINES_PER_STORY)) ] || full "size: $changed_lines changed lines for $stories story/stories (limit $LINES_PER_STORY per story)"
[ "$changed_files" -le $((stories * FILES_PER_STORY)) ] || full "size: $changed_files changed files for $stories story/stories (limit $FILES_PER_STORY per story)"

# --- path signals: migrations/schema, dependency manifests and lockfiles, endpoint and auth code ---
while IFS=$'\t' read -r status path; do
  base="${path##*/}"; lower="$(printf '%s' "$path" | tr '[:upper:]' '[:lower:]')"
  case "$path" in
    */migrations/*|migrations/*|*/migration/*|*/prisma/*|prisma/*|*/drizzle/*|drizzle/*|*.sql|*schema.prisma) full "migration/schema: $status $path" ;;
  esac
  case "$lower" in
    *schema*|models.py|*/models.py|*.entity.[jt]s|*.entity.py) full "migration/schema: $status $path" ;;
  esac
  case "$base" in
    package-lock.json|pnpm-lock.yaml|yarn.lock|bun.lock|bun.lockb|Cargo.lock|poetry.lock|uv.lock|Pipfile.lock|go.sum|Gemfile.lock|composer.lock) full "dependency: lockfile changed ($status $path)" ;;
    package.json|Cargo.toml|pyproject.toml|requirements*.txt|setup.py|setup.cfg|Pipfile|go.mod|Gemfile|*.gemspec|composer.json|pom.xml|build.gradle|build.gradle.kts|build.sbt|deno.json|deno.jsonc|pubspec.yaml|mix.exs|Package.swift|Podfile|packages.config|Directory.Packages.props|*.csproj|*.fsproj|*.vbproj|environment.yml|environment.yaml) full "dependency: manifest changed ($status $path)" ;;
  esac
  case "$path" in
    */api/*|api/*|*/routes/*|routes/*|*/route.[jt]s|*/route.[jt]sx|*/controllers/*|*/handlers/*|*/endpoints/*|*/resolvers/*|*/views.py|*/urls.py) full "endpoint code: $status $path" ;;
  esac
  case "$lower" in
    *auth*|*session*|*permission*|*access*|*acl*|*guard*|*middleware*|*login*|*policy*|*policies*|*rbac*|*security*|*csrf*|*cors*|*admin*|*credential*|*token*) full "auth/session/permission path: $status $path" ;;
  esac
done < <(git diff "${DIFF_OPTS[@]}" --name-status "$RANGE" -- . "${EXCLUDES[@]}")

# --- line signals: added and removed lines (-U0, so only changed lines) plus the hunk's enclosing function ---
read -r -d '' SIGNAL_AWK <<'AWK' || true
function note(name, sign, where) {
  count[name]++
  if (count[name] <= 2) ex[name] = ex[name] (ex[name] == "" ? "" : "; ") sign file
}
function scan(text, sign,    t) {
  t = tolower(text)
  gsub(/authoriz/, "authz", t); gsub(/author/, "", t) # an author field is not an auth path
  if (t ~ /innerhtml|v-html|dangerouslysetinnerhtml|\|[[:space:]]*safe|mark_safe|html_safe/) note("user input rendered (unescaped HTML sink)", sign)
  if (t ~ /auth|admin|role|owner|forbidden|guard|session|permission|csrf|password|jwt|access|allow|deny|grant|permit|login|logout|signin|signup|credential|token|secret|acl|policy|(^|[^0-9])40[13]([^0-9]|$)/) note("auth/session/permission path", sign)
  if (t ~ /insert into|update [a-z0-9_."`]+ set|delete from|create table|alter table|drop table|\.(insert|upsert|update|delete|destroy|save|create|createmany|bulkcreate|insertmany|insertone|updatemany|updateone|deletemany|deleteone|replaceone|persist)\(/) note("data persisted or deleted", sign)
  if (t ~ /\.(get|post|put|patch|delete|options|head|all|use|route)\([[:space:]]*["'`]\/|\.route\(|@(get|post|put|patch|delete|route|requestmapping|getmapping|postmapping|controller)\(|@[a-z_]+\.route\(|#\[[a-z_:]*(get|post|put|patch|delete|route)\(|export (async )?function (get|post|put|patch|delete)([^a-z]|$)|export const (get|post|put|patch|delete)([^a-z]|$)|(^|[^a-z_.])path\(|urlpatterns|procedure|defineeventhandler|map(get|post|put|patch|delete)\(/) note("endpoint or route handler", sign)
}
/^diff --git / { hdr = 1; file = ""; next }
hdr && /^\+\+\+ / { p = substr($0, 5); if (p != "/dev/null") file = substr(p, 3); next }
hdr && /^--- /   { p = substr($0, 5); if (file == "" && p != "/dev/null") file = substr(p, 3); next }
/^@@/ { hdr = 0; h = $0; sub(/^@@[^@]*@@/, "", h); if (h != "") scan(h, "~"); next } # ~ = enclosing function of the hunk
hdr { next }
/^[-+]/ { scan(substr($0, 2), substr($0, 1, 1)) }
END { for (n in count) printf "%s: %d line(s), e.g. %s\n", n, count[n], ex[n] }
AWK
signals="$(git diff "${DIFF_OPTS[@]}" -U0 "$RANGE" -- . "${EXCLUDES[@]}" | awk "$SIGNAL_AWK")"
if [ -n "$signals" ]; then
  while IFS= read -r line; do full "$line"; done <<<"$signals"
fi

finish
