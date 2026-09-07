#!/usr/bin/env node
// Command evidence for the agent-coordinated PROJ gate; no second scheduler.
import fs from 'node:fs';
import path from 'node:path';
import { createHash, randomUUID } from 'node:crypto';
import { execFileSync, spawnSync } from 'node:child_process';

const [proj, theme, action = 'check', kind, ...args] = process.argv.slice(2);
const git = (...args) => execFileSync('git', args, { encoding: 'utf8' }).trim();
const hash = value => createHash('sha256').update(value).digest('hex');
const base = `specs/PROJ-${proj}-${theme}`;
const progress = `${base}/5_progress`;
const configPath = `${base}/3-4_plan/wave-gate-config.json`;
const evidencePath = key => `${progress}/quality-${encodeURIComponent(key)}.json`;
const operational = name => name.startsWith(`${progress}/`) || [`${base}/state.json`, `${base}/findings.json`, `${base}/.findings.lock`].includes(name);
function snapshotFile(name) {
  const stat = fs.lstatSync(name);
  if (stat.isSymbolicLink()) throw new Error(`artifact/input symlink unsupported: ${name}`);
  if (stat.isDirectory()) return fs.readdirSync(name).sort().map(child => [child, snapshotFile(path.join(name, child))]);
  return hash(fs.readFileSync(name));
}
function inputs() {
  const changed = [...git('diff', '--name-only', 'HEAD', '-z').split('\0'), ...git('ls-files', '--others', '--exclude-standard', '-z').split('\0')].filter(Boolean);
  if (changed.some(name => !operational(name))) throw new Error('commit non-evidence changes before verification');
  // Evidence-only commits do not invalidate the code/configuration being verified.
  const tree = git('ls-tree', '-rz', 'HEAD').split('\0').filter(line => line && !operational(line.split('\t')[1]));
  const local = fs.readdirSync('.').filter(name => name === '.env' || name.startsWith('.env.'));
  for (const name of ['node_modules/.package-lock.json', 'node_modules/.modules.yaml']) if (fs.existsSync(name)) local.push(name);
  const installEpoch = fs.existsSync('node_modules') ? fs.statSync('node_modules').mtimeMs : null;
  return hash(JSON.stringify([tree, local.sort().map(name => [name, hash(fs.readFileSync(name))]), installEpoch, Object.entries(process.env).filter(([name]) => !['_', 'SHLVL', 'PWD', 'OLDPWD'].includes(name)).sort(), process.version, process.platform, process.arch]));
}
function artifacts(names) {
  if (!Array.isArray(names) || names.some(name => typeof name !== 'string' || !name.trim())) throw new Error('artifact paths must be non-empty strings');
  return names.map(name => [name, snapshotFile(name)]);
}
function selected(log) {
  // Same common runner summaries accepted by the wave gate: Vitest, TAP, pytest/Playwright.
  log = log.replace(/\x1b\[[0-9;]*m/g, '');
  const counts = [...log.matchAll(/(?:Tests\s+[^\n]*?([0-9]+)\s+passed|# tests\s+([0-9]+)|Running\s+([0-9]+)\s+tests?|(?:^|\n)\s*([0-9]+)\s+passed)/g)].map(m => Number(m.slice(1).find(v => v !== undefined)));
  return Math.max(0, ...counts);
}
function write(key, record) {
  const target = evidencePath(key), temp = `${target}.${randomUUID()}.tmp`;
  fs.writeFileSync(temp, JSON.stringify(record, null, 2) + '\n'); fs.renameSync(temp, target);
}
function commandFor(key, config) {
  if (key.startsWith('test:')) return (config.phase_commands ?? []).find(entry => entry.phase === 'quality' && entry.label === key.slice(5))?.command;
  return key === 'lint' ? config.lint_cmd ?? 'npm run lint' : config[`${key}_cmd`];
}
function valid(key, config, fingerprint) {
  const record = JSON.parse(fs.readFileSync(evidencePath(key), 'utf8'));
  if (record.inputs !== fingerprint || record.rc !== 0 || !record.head) throw new Error(`${key}: stale or failed evidence`);
  if (key !== 'review' && key !== 'sonar-skip' && record.command !== commandFor(key, config)) throw new Error(`${key}: command changed`);
  if (!record.log || snapshotFile(record.log) !== record.log_hash) throw new Error(`${key}: log missing or changed`);
  if (JSON.stringify(artifacts(record.artifacts.map(([name]) => name))) !== JSON.stringify(record.artifacts)) throw new Error(`${key}: artifacts missing or changed`);
  if ((key === 'coverage' || key.startsWith('test:')) && !(record.selected > 0)) throw new Error(`${key}: no tests selected`);
  return record;
}
function canSkip(reason) {
  const available = name => spawnSync('bash', ['-c', 'command -v "$1" >/dev/null', '_', name]).status === 0;
  if (reason === 'sonar CLI unavailable') return !available('sonar') || !available('sonar-scanner');
  return reason === 'project not configured' && !fs.existsSync('sonar-project.properties');
}
function main() {
  if (!proj || !theme || !/^[\w-]+$/.test(proj) || !/^[\w-]+$/.test(theme)) throw new Error('Usage: quality-evidence.mjs PROJ THEME [check|snapshot|run KIND|record-build LOG HEAD INPUTS|review REPORT|skip-sonar REASON]');
  if (fs.realpathSync('.') !== fs.realpathSync(git('rev-parse', '--show-toplevel'))) throw new Error('run from the worktree root');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const fingerprint = inputs();
  if (action === 'snapshot') { console.log(fingerprint); return; }
  if (action === 'check') {
    for (const key of ['build', 'lint', 'review', ...(config.coverage_cmd ? ['coverage'] : []), ...(config.phase_commands ?? []).filter(e => e.phase === 'quality').map(e => `test:${e.label}`)]) valid(key, config, fingerprint);
    if (fs.existsSync(evidencePath('sonar-skip'))) {
      const skip = valid('sonar-skip', config, fingerprint);
      if (!canSkip(skip.reason)) throw new Error('Sonar skip no longer valid');
    } else valid('sonar', config, fingerprint);
    console.log('✓ PROJ command evidence matches current inputs, commands, logs and artifacts'); return;
  }
  if (action === 'review' || action === 'skip-sonar') {
    const key = action === 'review' ? 'review' : 'sonar-skip';
    if (action === 'skip-sonar' && !canSkip(kind)) throw new Error('invalid Sonar skip');
    const log = action === 'review' ? kind : `${progress}/quality-sonar-skip.log`;
    if (action === 'skip-sonar') fs.writeFileSync(log, kind + '\n');
    if (!fs.readFileSync(log, 'utf8').trim()) throw new Error('review report is empty');
    write(key, { head: git('rev-parse', 'HEAD'), inputs: fingerprint, rc: 0, log, log_hash: snapshotFile(log), artifacts: [], reason: action === 'skip-sonar' ? kind : undefined }); return;
  }
  if (action !== 'run' && action !== 'record-build') throw new Error('unknown action');
  const key = action === 'record-build' ? 'build' : kind;
  const command = commandFor(key, config);
  if (!command?.trim()) throw new Error(`missing command for ${key}`);
  const artifactNames = config[`${key}_artifacts`] ?? [];
  if (key === 'coverage' && !artifactNames.length) throw new Error('coverage requires declared artifacts');
  if (action === 'run' && ['build', 'coverage'].includes(key) && artifactNames.length) {
    try {
      const previous = valid(key, config, fingerprint);
      if (JSON.stringify(previous.artifacts.map(([name]) => name)) !== JSON.stringify(artifactNames)) throw new Error('artifact configuration changed');
      console.log(`✓ reused ${key}: ${previous.log}`); return;
    } catch { /* Missing/stale evidence requires an actual command. */ }
  }
  if (key === 'sonar' && config.coverage_cmd) valid('coverage', config, fingerprint);
  fs.rmSync(evidencePath(key), { force: true });
  if (key === 'sonar') fs.rmSync(evidencePath('sonar-skip'), { force: true });
  const started = Date.now(), head = git('rev-parse', 'HEAD');
  let log, rc;
  if (action === 'record-build') {
    // Called only by wave-gate after its build process exits 0 and HEAD/clean checks pass.
    log = kind;
    if (args[0] !== head || args[1] !== fingerprint) throw new Error('wave build inputs changed');
    rc = 0;
  } else {
    log = `${progress}/quality-${encodeURIComponent(key)}-${randomUUID()}.log`;
    const fd = fs.openSync(log, 'w');
    const seconds = Number(config.timeouts?.[`${key}_seconds`] ?? config.timeouts?.ac_seconds ?? 600);
    if (!Number.isFinite(seconds) || seconds <= 0) throw new Error('invalid command timeout');
    let invocation = ['bash', '-c', command];
    const phase = (config.phase_commands ?? []).find(e => `test:${e.label}` === key);
    if (phase?.auth_consuming) {
      if (!config.auth_budget?.preflight_cmd || !fs.existsSync('scripts/worktree.sh')) throw new Error('auth quality command requires preflight and shared lock helper');
      invocation = ['bash', 'scripts/worktree.sh', 'with-shared-lock', '--', 'bash', '-c', 'bash -c "$1" && bash -c "$2"', '_', config.auth_budget.preflight_cmd, command];
    }
    const result = spawnSync('timeout', ['--kill-after=5s', String(seconds), ...invocation], { stdio: ['ignore', fd, fd] });
    fs.closeSync(fd); rc = result.status ?? 1;
  }
  const output = fs.readFileSync(log, 'utf8');
  const count = selected(output);
  if ((key === 'coverage' || key.startsWith('test:')) && !count) rc ||= 1;
  if (inputs() !== fingerprint || git('rev-parse', 'HEAD') !== head) rc ||= 1;
  let files = [];
  if (rc === 0) {
    if (key === 'sonar') {
      const task = '.scannerwork/report-task.txt';
      if (!fs.existsSync(task) || fs.statSync(task).mtimeMs < started || !/^ceTaskId=.+/m.test(fs.readFileSync(task, 'utf8'))) throw new Error('Sonar produced no fresh task receipt');
      files = artifacts([task]);
    } else files = artifacts(artifactNames);
  }
  write(key, { head, inputs: fingerprint, command, rc, selected: count, log, log_hash: snapshotFile(log), artifacts: files });
  if (rc) throw new Error(`${key} failed (${rc}); log: ${log}`);
  if (key === 'sonar') fs.rmSync(evidencePath('sonar-skip'), { force: true });
  console.log(`✓ ${key}: ${log}`);
}
try { main(); } catch (error) { console.error(`quality evidence: ${error.message}`); process.exitCode = 1; }
