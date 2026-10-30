#!/usr/bin/env bash
# `chain check risk`: the fast|full QA profile decision, against fixture repos. A fast-track PROJ is
# `fast` only with the marker and no risk signal; guard removal, new endpoints, dependencies,
# migrations, persisted data, unescaped sinks and an oversized diff are `full`; anything unreadable
# is `full`. Both provider copies must behave identically.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CASE="$(mktemp -d)"
trap 'rm -rf "$CASE"' EXIT
die() { echo "risk-check: $*" >&2; exit 1; }

for provider in claude codex; do
  SKILLS="$ROOT/$provider/skills"
  FIX="$CASE/$provider"; mkdir -p "$FIX/scripts" "$FIX/specs/PROJ-95-fixture"/{1_concept,2_PRDs} "$FIX/src" "$FIX/tests"
  cd "$FIX"
  git init -q -b main; git config user.email t@local; git config user.name t
  for s in 5_executing/scripts/chain 5_executing/scripts/state.sh 5_executing/scripts/compat.sh 6_qa/scripts/risk-check.sh; do cp "$SKILLS/$s" scripts/; done
  chmod +x scripts/*.sh scripts/chain
  printf '# Concept\n\n## Handoff Readiness\n- Delivery track: full chain (in-repo build)\n- Authored via: fast-track-spec\n' >specs/PROJ-95-fixture/1_concept/PROJ-95-concept.md
  printf '# PRD 1\n\n### US-1: As a user, I want a greeting so that I am welcomed\n' >specs/PROJ-95-fixture/2_PRDs/PROJ-95-PRD-1-greeting.md
  printf 'export const greet = (n) => `hello ${n}`;\n' >src/greet.js
  printf 'export function handle(user) {\n  if (!user.isAdmin) return 403;\n  return 200;\n}\n' >src/handler.js
  printf 'export function canAccess(user) {\n  const ok = false;\n  return ok;\n}\n' >src/lib.js
  printf 'export const allowed = false;\n' >src/access.ts
  printf 'const server = 1;\n' >src/server.js
  printf '//go:build auth\npackage gate\n\nfunc Run() {}\n' >src/gate.go
  printf 'class Worker {\n  void Execute() {\n#if REQUIRE_LOGIN\n    CheckLogin();\n#endif\n  }\n}\n' >src/worker.cs
  printf '{\n  "name": "fixture",\n  "version": "1.0.0",\n  "scripts": { "test": "node --test" },\n  "dependencies": { "left-pad": "^1.0.0" }\n}\n' >package.json
  git add -A; git commit -qm base; BASE="$(git rev-parse HEAD)"
  risk() { bash scripts/chain check risk 95 fixture "$@"; }
  # expect <name> <fast|full> [needle]: the verdict is line 1; a needle must appear among the reasons
  expect() {
    local name="$1" want="$2" needle="${3:-}" out
    git add -A; git commit -qm "$name"
    out="$(risk --base "$BASE")" || die "$provider/$name: risk-check failed"
    [ "$(sed -n 1p <<<"$out")" = "$want" ] || die "$provider/$name: expected $want, got: $out"
    [ -z "$needle" ] || grep -qiE -- "$needle" <<<"$out" || die "$provider/$name: reasons lack '$needle': $out"
  }
  fresh() { git checkout -q -B "$1" "$BASE"; }
  manifest() { printf '{\n  "name": "fixture",\n  "version": "1.0.0",\n  "scripts": { "test": "node --test" },\n  "dependencies": { %s }\n}\n' "$1" >package.json; }

  fresh benign;      printf 'export const wave = (n) => `hi ${n}`;\n' >src/wave.js
  mkdir -p tests; printf 'author note\n' >tests/auth.test.js # tests are never signals; an author field is not an auth path
  printf 'const author = "x";\n' >>src/wave.js
  expect benign fast 'no risk signal'

  fresh guard-removed; printf 'export function handle(user) {\n  return 200;\n}\n' >src/handler.js
  expect guard-removed full 'auth/session/permission.*-src/handler.js'

  fresh guard-added;   printf 'export function handle(user) {\n  if (!user.isAdmin) return 403;\n  if (!user.verified) return 403;\n  return 200;\n}\n' >src/handler.js
  expect guard-added full 'auth/session/permission'

  fresh new-route;     printf 'app.post("/greet", (req, res) => res.send("ok"));\n' >src/server.js
  expect new-route full 'endpoint or route handler'

  fresh new-route-file; mkdir -p src/api; printf 'export default () => 1;\n' >src/api/greet.js
  expect new-route-file full 'endpoint code: A src/api/greet.js'

  fresh new-dependency; manifest '"left-pad": "^1.0.0", "chalk": "^5.0.0"'
  expect new-dependency full 'dependency'

  fresh dep-bump;      manifest '"left-pad": "^1.3.0"'
  expect dep-bump full 'dependency'

  fresh lockfile;      printf '{}\n' >package-lock.json; printf 'export const x = 1;\n' >src/x.js
  expect lockfile full 'lockfile'

  fresh migration;     mkdir -p db/migrations; printf 'select 1;\n' >db/migrations/001_init.sql; printf 'export const x = 1;\n' >src/x.js
  expect migration full 'migration/schema'

  fresh persisted;     printf 'export const save = (db, v) => db.insert(v);\n' >src/save.js
  expect persisted full 'data persisted'

  fresh html-sink;     printf 'export const show = (el, v) => { el.innerHTML = v; };\n' >src/show.js
  expect html-sink full 'unescaped HTML sink'

  fresh oversized;     awk 'BEGIN { for (i = 0; i < 200; i++) printf "export const v%d = %d;\n", i, i }' >src/big.js
  expect oversized full 'size: 200 changed lines'

  fresh tests-only;    mkdir -p tests; printf 'it("x", () => { /* auth */ });\n' >tests/only.test.js
  expect tests-only full 'no production-code change'

  # review findings: a risky change on a line with no signal word must still be caught via path or enclosing function
  fresh flip-in-auth-path; printf 'export const allowed = true;\n' >src/access.ts
  expect flip-in-auth-path full 'auth/session/permission path: M src/access.ts'
  fresh flip-in-function;  printf 'export function canAccess(user) {\n  const ok = true;\n  return ok;\n}\n' >src/lib.js
  expect flip-in-function full 'auth/session/permission path: .*~src/lib.js'
  fresh fastify-route;     printf 'const server = 1;\nfastify.route({ method: "POST", url: "/transfer", handler });\n' >src/server.js
  expect fastify-route full 'endpoint or route handler'
  fresh router-get;        printf 'const server = 1;\nr.get("/health", h);\n' >src/server.js
  expect router-get full 'endpoint or route handler'
  fresh cargo-dep;         printf '[dependencies]\nserde = { version = "1" }\n' >Cargo.toml
  expect cargo-dep full 'dependency: manifest changed'
  fresh pyproject-dep;     printf '[project]\ndependencies = ["requests = { version = 2.32 }"]\n' >pyproject.toml
  expect pyproject-dep full 'dependency: manifest changed'
  fresh pubspec-dep;       printf 'dependencies:\n  http: ^1.0.0\n' >pubspec.yaml
  expect pubspec-dep full 'dependency: manifest changed'
  fresh csproj-dep;        printf '<Project><ItemGroup><PackageReference Include="X" Version="1" /></ItemGroup></Project>\n' >app.csproj
  expect csproj-dep full 'dependency: manifest changed'
  fresh orm-create;        printf 'export const add = (db, v) => db.item.create({ data: v });\n' >src/store.ts
  expect orm-create full 'data persisted'

  # calibration (read-only runs over four sibling repos): Markdown prose carries no behavior
  fresh docs-prose;        mkdir -p docs src/auth; printf '# Auth\nPOST /login stores the session token for the admin role.\napp.post("/x", h)\n' >docs/auth.md; printf 'See owner and allow lists.\n' >src/auth/README.md; printf 'export const wave = (n) => `hi ${n}`;\n' >src/wave.js
  expect docs-prose fast 'no risk signal'
  fresh docs-only;         mkdir -p docs; printf 'session token\n' >docs/guide.md; printf '# Notes\n' >NOTES.md
  expect docs-only full 'no production-code change'
  # comment lines stay in the scan: build directives, preprocessor lines and annotations carry behavior (review rounds 3 to 5)
  fresh comment-words;     printf '// guard: check the session role before the admin may access it\nexport const wave = (n) => `hi ${n}`;\n' >src/wave.js
  expect comment-words full 'auth/session/permission'
  fresh go-build-tag;      printf '//go:build !auth\npackage gate\n\nfunc Run() {}\n' >src/gate.go
  expect go-build-tag full 'auth/session/permission'
  fresh code-and-comment;  printf 'export const f = (user) => { if (!user.isAdmin) return 403; }; // guard\n' >src/wave.js
  expect code-and-comment full 'auth/session/permission'
  # review round 3: executable files must not hide behind the docs/MDX path, and code after a closed comment still counts
  fresh mdx-component;     printf 'export const Demo = ({ v }) => <div dangerouslySetInnerHTML={{ __html: v }} />;\n' >src/Demo.mdx; printf 'export const wave = (n) => `hi ${n}`;\n' >src/wave.js
  expect mdx-component full 'unescaped HTML sink'
  fresh docs-code;         mkdir -p docs/api; printf 'app.post("/transfer", handler);\n' >docs/api/server.js; printf 'export const wave = (n) => `hi ${n}`;\n' >src/wave.js
  expect docs-code full 'endpoint or route handler'
  fresh code-after-block;  printf '/* note */ db.item.create({ data: v });\n' >src/wave.js
  expect code-after-block full 'data persisted'
  fresh code-after-close;  printf '/**\n * note\n */ db.item.create({ data: v });\n' >src/wave.js
  expect code-after-close full 'data persisted'
  fresh code-after-html;   printf '<!-- note --> <div v-html="x"></div>\n' >src/view.vue
  expect code-after-html full 'unescaped HTML sink'
  fresh preproc-directive; printf 'class Worker {\n  void Execute() {\n#if false\n    CheckLogin();\n#endif\n  }\n}\n' >src/worker.cs
  expect preproc-directive full 'auth/session/permission'
  fresh rust-attribute;    printf '#[get("/greet")]\nasync fn greet() {}\n' >src/greet.rs
  expect rust-attribute full 'endpoint or route handler'
  fresh shebang-flag;      printf '#!/usr/bin/env node\nconst token = process.env.TOKEN;\n' >src/cli.js
  expect shebang-flag full 'auth/session/permission'

  # review of PR #34: schema files outside migration dirs, binary files and uncommitted work cannot read as fast
  fresh schema-file;       mkdir -p src/db; printf 'export const customers = pgTable("customers", { note: text("note") });\n' >src/db/schema.ts
  expect schema-file full 'migration/schema: A src/db/schema.ts'
  fresh binary-file;       printf '\000\001\002\377' >src/module.wasm
  expect binary-file full 'binary file changed'
  fresh dirty-tree;        printf 'export const wave = (n) => `hi ${n}`;\n' >src/wave.js; git add -A; git commit -qm dirty-tree
  printf 'export function handle(user) {\n  return 200;\n}\n' >src/handler.js
  [ "$(risk --base "$BASE" | sed -n 1p)" = full ] && risk --base "$BASE" | grep -q 'uncommitted production-code' || die "$provider: an uncommitted guard removal must read full"
  git checkout -q -- src/handler.js; printf 'x\n' >src/new-untracked.js
  risk --base "$BASE" | grep -q 'uncommitted production-code' || die "$provider: an untracked production file must read full"
  rm src/new-untracked.js
  [ "$(risk --base "$BASE" | sed -n 1p)" = fast ] || die "$provider: a clean tree must stay fast again"

  # no marker and a missing concept are full, always
  fresh no-marker;     printf '# Concept\n\n## Handoff Readiness\n- Delivery track: full chain (in-repo build)\n' >specs/PROJ-95-fixture/1_concept/PROJ-95-concept.md; printf 'export const x = 1;\n' >src/x.js
  expect no-marker full 'no .Authored via: fast-track-spec. marker'
  fresh marker-elsewhere;  printf '# Concept\n\n## Handoff Readiness\n- Delivery track: full chain (in-repo build)\n\n## Notes\n- Authored via: fast-track-spec\n' >specs/PROJ-95-fixture/1_concept/PROJ-95-concept.md; printf 'export const x = 1;\n' >src/x.js
  expect marker-elsewhere full 'no .Authored via: fast-track-spec. marker'
  fresh marker-prefix;     printf '# Concept\n\n## Handoff Readiness\n- Authored via: fast-track-spec-disabled\n' >specs/PROJ-95-fixture/1_concept/PROJ-95-concept.md; printf 'export const x = 1;\n' >src/x.js
  expect marker-prefix full 'no .Authored via: fast-track-spec. marker'
  fresh marker-formatted;  printf '# Concept\n\n## Handoff Readiness\n- `Delivery track: full chain (in-repo build)`\n- `Authored via: fast-track-spec`\n\n## Next Step\n- x\n' >specs/PROJ-95-fixture/1_concept/PROJ-95-concept.md; printf 'export const x = 1;\n' >src/x.js
  expect marker-formatted fast 'no risk signal'
  fresh marker-inline;     printf '# Concept\n\n## Handoff Readiness\n- `Delivery track: full chain (in-repo build)`; `Authored via: fast-track-spec`\n' >specs/PROJ-95-fixture/1_concept/PROJ-95-concept.md; printf 'export const x = 1;\n' >src/x.js
  expect marker-inline full 'no .Authored via: fast-track-spec. marker'
  fresh no-concept;    rm specs/PROJ-95-fixture/1_concept/PROJ-95-concept.md; printf 'export const x = 1;\n' >src/x.js
  expect no-concept full 'no readable concept'

  # base from state.json (.base_sha) and the unreadable-base fallbacks
  fresh from-state;    printf 'export const x = 1;\n' >src/x.js; git add -A; git commit -qm from-state
  bash scripts/chain state init 95 fixture >/dev/null
  bash scripts/chain state set 95 fixture .base_sha "\"$BASE\"" >/dev/null
  [ "$(risk | sed -n 1p)" = fast ] || die "$provider: base_sha from state.json not used: $(risk)"
  bash scripts/chain state set 95 fixture .base_sha '"0000000000000000000000000000000000000000"' >/dev/null
  [ "$(risk | sed -n 1p)" = full ] && risk | grep -q 'not in this repository' || die "$provider: unknown base commit must be full"
  [ "$(risk --base "$(git rev-parse HEAD)" | sed -n 1p)" = full ] || die "$provider: empty diff must be full"
  git checkout -q -B sibling "$BASE"; printf 'export const y = 1;\n' >src/y.js; git add -A; git commit -qm sibling
  sibling_sha="$(git rev-parse HEAD)"; git checkout -q from-state
  [ "$(risk --base "$sibling_sha" | sed -n 1p)" = full ] && risk --base "$sibling_sha" | grep -q 'not an ancestor' || die "$provider: a base that is not an ancestor of HEAD must be full"
  rc=0; bash scripts/chain check risk 95 >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 64 ] || die "$provider: missing theme must exit 64 (rc=$rc)"
  rc=0; risk --bogus >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 64 ] || die "$provider: unknown option must exit 64 (rc=$rc)"
done
echo "risk-check: ok"
