#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
const root = process.cwd(), temp = fs.mkdtempSync(path.join(os.tmpdir(), 'quality-evidence-'));
try {
  for (const platform of ['codex', 'claude']) {
    const cwd = path.join(temp, platform); fs.mkdirSync(cwd);
    const base = 'specs/PROJ-1-test', progress = `${base}/5_progress`;
    const write = (name, value) => fs.writeFileSync(path.join(cwd, name), value);
    const git = (...args) => execFileSync('git', args, { cwd, stdio: 'pipe' });
    const helper = path.join(root, platform, 'skills/5_executing/scripts/quality-evidence.mjs');
    const call = (...args) => spawnSync('node', [helper, '1', 'test', ...args], { cwd, encoding: 'utf8' });
    const ok = (...args) => { const r = call(...args); assert.equal(r.status, 0, r.stderr); return r.stdout; };
    const bad = (...args) => { const r = call(...args); assert.notEqual(r.status, 0, r.stdout); return r.stderr; };
    fs.mkdirSync(path.join(cwd, `${base}/3-4_plan`), { recursive: true });
    fs.mkdirSync(path.join(cwd, progress), { recursive: true });
    write('.gitignore', 'out/\ncoverage/\n.scannerwork/\n.env.local\nnode_modules/\n');
    write('source.txt', 'one');
    const config = {
      build_cmd: `mkdir -p out; echo build >> ${progress}/counter.log; echo output > out/build`, build_artifacts: ['out'],
      coverage_cmd: 'mkdir -p coverage; echo lcov > coverage/lcov.info; echo "Tests  2 passed (2)"', coverage_artifacts: ['coverage/lcov.info'],
      sonar_cmd: 'mkdir -p .scannerwork; echo ceTaskId=123 > .scannerwork/report-task.txt',
      lint_cmd: 'true', phase_commands: [{ label: 'integration', phase: 'quality', command: 'echo "# tests 3"' }]
    };
    const saveConfig = () => write(`${base}/3-4_plan/wave-gate-config.json`, JSON.stringify(config)); saveConfig();
    git('init', '-q'); git('config', 'user.name', 'test'); git('config', 'user.email', 'test@example.invalid');
    const commit = () => { git('add', '.'); git('commit', '-qm', 'fixture'); }; commit();
    bad('check'); ok('run', 'build'); assert.match(ok('run', 'build'), /reused/);
    assert.equal(fs.readFileSync(path.join(cwd, `${progress}/counter.log`), 'utf8'), 'build\n');
    write('out/build', 'tampered'); assert.doesNotMatch(ok('run', 'build'), /reused/);
    fs.rmSync(path.join(cwd, 'out'), { recursive: true }); assert.doesNotMatch(ok('run', 'build'), /reused/);
    write('.env.local', 'SETTING=new'); assert.doesNotMatch(ok('run', 'build'), /reused/);
    bad('run', 'sonar'); // coverage must finish first
    ok('run', 'coverage'); assert.match(ok('run', 'coverage'), /reused/);
    ok('run', 'sonar'); ok('run', 'lint'); ok('run', 'test:integration');
    write(`${progress}/review.md`, 'Reviewed integration; no P0/P1 findings.'); ok('review', `${progress}/review.md`);
    ok('check');
    const buildProof = JSON.parse(fs.readFileSync(path.join(cwd, `${progress}/quality-build.json`), 'utf8'));
    const savedLog = fs.readFileSync(path.join(cwd, buildProof.log));
    write(buildProof.log, 'tampered log'); bad('check'); write(buildProof.log, savedLog); ok('check');
    const statuses = ['Code Review', 'Build', 'Tests', 'Lint'].map(name => `### ${name}\nStatus: passed\n`).join('');
    write(`${progress}/PROJ-1-progress.md`, `## Quality Gate — PROJ-1\n${statuses}### SonarCloud\nStatus: ran\n`);
    const proof = () => spawnSync('bash', [path.join(root, platform, 'skills/5_executing/scripts/quality-gate-proof.sh'), '1', 'test'], { cwd, encoding: 'utf8' });
    // This fixture's .env.local is not sourced for direct helper calls.
    const sourceEnv = process.env.SETTING; process.env.SETTING = 'new';
    assert.notEqual(proof().status, 0, 'environment change must invalidate apparently green statuses');
    if (sourceEnv === undefined) delete process.env.SETTING; else process.env.SETTING = sourceEnv;
    fs.rmSync(path.join(cwd, '.env.local')); // re-verify all commands with one environment
    ok('run', 'build'); ok('run', 'coverage'); ok('run', 'sonar'); ok('run', 'lint'); ok('run', 'test:integration'); ok('review', `${progress}/review.md`);
    assert.equal(proof().status, 0, proof().stderr);
    commit(); ok('check'); // committing operational evidence preserves code proof
    write('source.txt', 'two'); bad('check'); assert.notEqual(proof().status, 0, 'stale green markdown must fail'); bad('run', 'build'); commit(); bad('check');
    assert.doesNotMatch(ok('run', 'build'), /reused/);
    config.phase_commands[0].command = 'echo no-tests'; saveConfig(); commit(); bad('run', 'test:integration');
    config.coverage_cmd = 'exit 7'; saveConfig(); commit(); bad('run', 'coverage'); bad('run', 'sonar');
    config.coverage_cmd = 'mkdir -p coverage; echo lcov > coverage/lcov.info; echo "# tests 2"';
    config.sonar_cmd = 'true'; saveConfig(); commit(); ok('run', 'coverage'); bad('run', 'sonar');
    fs.mkdirSync(path.join(cwd, 'scripts'));
    fs.copyFileSync(path.join(root, platform, 'skills/5_executing/scripts/worktree.sh'), path.join(cwd, 'scripts/worktree.sh'));
    config.auth_budget = { preflight_cmd: 'true' };
    config.phase_commands = [{ label: 'auth', phase: 'quality', auth_consuming: true, command: `test -e /proc/$$/fd/8 && echo called >> ${progress}/auth-calls.log && echo "# tests 1"` }];
    saveConfig(); commit(); ok('run', 'test:auth');
    config.auth_budget.preflight_cmd = 'exit 75'; saveConfig(); commit(); bad('run', 'test:auth');
    assert.equal(fs.readFileSync(path.join(cwd, `${progress}/auth-calls.log`), 'utf8'), 'called\n');
    config.build_cmd = 'exit 8'; saveConfig(); commit(); bad('run', 'build');
    const failedBuild = JSON.parse(fs.readFileSync(path.join(cwd, `${progress}/quality-build.json`), 'utf8')); assert.equal(failedBuild.rc, 8);
  }
  console.log('quality evidence behavior tests (codex + claude): PASS');
} finally { fs.rmSync(temp, { recursive: true, force: true }); }
