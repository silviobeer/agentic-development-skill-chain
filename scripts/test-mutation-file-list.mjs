#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync, spawn } from 'node:child_process';

const root = process.cwd(), temp = fs.mkdtempSync(path.join(os.tmpdir(), 'mutation-scope-'));
try {
  for (const provider of ['claude', 'codex']) {
    const cwd = path.join(temp, provider); fs.mkdirSync(cwd);
    const base = 'specs/PROJ-1-test', progress = `${base}/5_progress`;
    fs.mkdirSync(path.join(cwd, `${base}/3-4_plan`), { recursive: true });
    fs.mkdirSync(path.join(cwd, progress), { recursive: true });
    const write = (name, value) => fs.writeFileSync(path.join(cwd, name), value);
    const git = (...args) => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: 'pipe' });
    const commit = () => { git('add', '.', ':(exclude)specs/PROJ-1-test/5_progress/**'); git('commit', '--allow-empty', '-qm', 'fixture'); };
    git('init', '-q'); git('config', 'user.name', 'test'); git('config', 'user.email', 'test@example.invalid');
    write('deleted.txt', 'old'); write('unchanged.txt', 'keep'); commit();
    git('tag', 'proj-PROJ-1-base'); const baseSha = git('rev-parse', 'HEAD').trim();
    const names = [' source.txt', 'space name.txt', '日本語-é.txt', 'quote\'".txt', 'line\nbreak\n.txt'];
    for (const name of names) write(name, 'changed');
    fs.unlinkSync(path.join(cwd, 'deleted.txt'));
    const capture = `${progress}/scope.json`;
    write('wrapper.mjs', `import fs from 'node:fs';
import assert from 'node:assert/strict';
const file = process.env.CHANGED_FILES_FILE;
assert.ok(file && file.startsWith('/'), 'missing absolute file-list path');
assert.equal(process.env.CHANGED_FILES, undefined, 'legacy scope leaked');
const bytes = fs.readFileSync(file);
assert.ok(bytes.length > 0 && bytes.at(-1) === 0, 'missing NUL terminator');
// Publish the signal-readiness marker only after its JSON is complete.
fs.writeFileSync(${JSON.stringify(capture + '.tmp')}, JSON.stringify({file, base: process.env.BASE_SHA, files: bytes.toString('utf8').split('\\0').slice(0, -1)}));
fs.renameSync(${JSON.stringify(capture + '.tmp')}, ${JSON.stringify(capture)});
console.log('Mutants: 5'); console.log('Survivors: 0');
`);
    const config = { mutation_cmd: 'node wrapper.mjs', timeouts: { mutation_seconds: 10 } };
    const save = () => write(`${base}/3-4_plan/wave-gate-config.json`, JSON.stringify(config));
    save(); commit();
    const script = path.join(root, provider, 'skills/5_executing/scripts/quality.mjs');
    const call = (env = {}) => spawnSync(process.execPath, [script, '1', 'test', 'run', 'mutation'], {
      cwd, encoding: 'utf8', env: { ...process.env, CHANGED_FILES: 'wrong legacy scope', CHANGED_FILES_FILE: '/wrong/inherited/path', ...env }
    });
    const check = expected => {
      const r = call(); assert.equal(r.status, expected, r.stderr);
      const scope = JSON.parse(fs.readFileSync(path.join(cwd, capture), 'utf8'));
      assert.equal(scope.base, baseSha);
      assert.deepEqual(scope.files.sort(), [...names, 'wrapper.mjs', `${base}/3-4_plan/wave-gate-config.json`].sort());
      assert.ok(!fs.existsSync(scope.file), 'file list leaked');
      assert.ok(!fs.existsSync(path.dirname(scope.file)), 'temporary directory leaked');
      return r;
    };
    check(0);
    config.mutation_cmd = 'node wrapper.mjs; exit 2'; save(); commit(); check(1);
    config.mutation_cmd = 'node wrapper.mjs; echo "Survivors: 2"; exit 1'; save(); commit(); check(1);
    config.mutation_cmd = 'node wrapper.mjs; echo "Survivors: 2"; kill -KILL "$PPID"'; save(); commit(); check(1);
    assert.equal(JSON.parse(fs.readFileSync(path.join(cwd, `${progress}/quality-mutation.json`), 'utf8')).rc, 137, 'killed runner must not become survivor evidence');
    config.timeouts.mutation_seconds = 5;
    config.mutation_cmd = 'node wrapper.mjs; sleep 30'; save(); commit();
    assert.match(check(1).stderr, /failed \(124\)/);
    for (const [signal, exitCode] of Object.entries({ SIGHUP: 129, SIGINT: 130, SIGQUIT: 131, SIGTERM: 143 })) {
      config.timeouts.mutation_seconds = 30;
      config.mutation_cmd = `trap '' TERM; echo "$BASHPID" > ${progress}/resistant.pid; node wrapper.mjs; echo "Survivors: 2"; sleep 30`; save(); commit();
      fs.unlinkSync(path.join(cwd, capture));
      const child = spawn(process.execPath, [script, '1', 'test', 'run', 'mutation'], { cwd, stdio: 'ignore' });
      const closed = new Promise(resolve => child.once('close', resolve));
      const deadline = Date.now() + 30000;
      while (!fs.existsSync(path.join(cwd, capture)) && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 10));
      if (!fs.existsSync(path.join(cwd, capture))) { child.kill('SIGKILL'); assert.fail('wrapper did not start'); }
      const scope = JSON.parse(fs.readFileSync(path.join(cwd, capture), 'utf8'));
      child.kill(signal);
      await new Promise(resolve => setTimeout(resolve, 80));
      const resistantPid = Number(fs.readFileSync(path.join(cwd, `${progress}/resistant.pid`), 'utf8').trim());
      const resistantState = spawnSync('ps', ['-p', String(resistantPid), '-o', 'stat='], { encoding: 'utf8' });
      const resistantAlive = resistantState.status === 0 && resistantState.stdout.trim() && !resistantState.stdout.trim().startsWith('Z');
      if (resistantAlive) assert.ok(fs.existsSync(scope.file), `${signal} removed mutation scope before resistant command cleanup completed`);
      child.kill(signal);
      assert.equal(await closed, 1, 'interrupted run must fail');
      const record = JSON.parse(fs.readFileSync(path.join(cwd, `${progress}/quality-mutation.json`), 'utf8'));
      assert.equal(record.rc, exitCode, 'cancellation must not become survivor evidence');
      assert.ok(!fs.existsSync(path.dirname(scope.file)), `${signal} leaked the file list`);
    }
    // A failed Git scope lookup must never run the wrapper against a broader scope.
    fs.unlinkSync(path.join(cwd, capture)); git('tag', '-d', 'proj-PROJ-1-base');
    assert.notEqual(call().status, 0); assert.ok(!fs.existsSync(path.join(cwd, capture)));
    git('tag', 'proj-PROJ-1-base', baseSha);
    // Empty scope remains empty, never a whole-repo fallback.
    config.mutation_cmd = `node -e 'const fs=require("fs"); const p=process.env.CHANGED_FILES_FILE; fs.writeFileSync("${capture}",JSON.stringify({file:p,size:fs.statSync(p).size})); if(fs.readFileSync(p).length) process.exit(2); console.error("empty scope"); process.exit(2)'`;
    save(); commit(); git('tag', '-f', 'proj-PROJ-1-base', 'HEAD');
    assert.notEqual(call().status, 0);
    const emptyScope = JSON.parse(fs.readFileSync(path.join(cwd, capture), 'utf8'));
    assert.equal(emptyScope.size, 0, 'empty diff must produce an empty file list');
    assert.ok(!fs.existsSync(emptyScope.file));
    // Failure to spawn timeout also removes the list (only Git remains on PATH).
    const bin = path.join(temp, `${provider}-bin`); fs.mkdirSync(bin);
    fs.symlinkSync(execFileSync('which', ['git'], { encoding: 'utf8' }).trim(), path.join(bin, 'git'));
    const isolatedTmp = path.join(temp, `${provider}-tmp`); fs.mkdirSync(isolatedTmp);
    assert.notEqual(call({ PATH: bin, TMPDIR: isolatedTmp }).status, 0);
    assert.deepEqual(fs.readdirSync(isolatedTmp), [], 'spawn failure leaked a temporary list');
    const realGit = execFileSync('which', ['git'], { encoding: 'utf8' }).trim();
    fs.unlinkSync(path.join(bin, 'git'));
    fs.writeFileSync(path.join(bin, 'git'), `#!/bin/bash\nfor arg; do [[ "$arg" != '--diff-filter=d' ]] || exit 2; done\nexec '${realGit}' "$@"\n`, { mode: 0o755 });
    fs.unlinkSync(path.join(cwd, capture));
    assert.notEqual(call({ PATH: bin, TMPDIR: isolatedTmp }).status, 0);
    assert.ok(!fs.existsSync(path.join(cwd, capture)), 'wrapper ran after Git scope failure');
    assert.deepEqual(fs.readdirSync(isolatedTmp), [], 'Git failure leaked a temporary list');
  }
  console.log('mutation file list (claude + codex): PASS');
} finally { fs.rmSync(temp, { recursive: true, force: true }); }
