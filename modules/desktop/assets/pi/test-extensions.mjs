// Offline checks against the actual pinned Pi loader, extension sources and LSP binaries.
// No real HOME, credentials, provider calls, child model runs or host activation.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const [piDir, bundle] = process.argv.slice(2);
const load = (path) => import(pathToFileURL(path).href);
const json = (path) => JSON.parse(readFileSync(path, 'utf8'));
const { discoverAndLoadExtensions, loadSkillsFromDir } = await load(join(piDir, 'dist/index.js'));
const { createJiti } = await load(join(piDir, 'node_modules/jiti/lib/jiti.mjs'));
const themeModule = await load(join(piDir, 'dist/modes/interactive/theme/theme.js'));
themeModule.initTheme('dark', false);
const manifest = json(join(bundle, 'package.json'));
assert.equal(manifest.dependencies['@specode/pi-subscription-usage'], undefined);
for (const resource of [...manifest.pi.extensions, ...manifest.pi.skills]) {
  assert.ok(existsSync(join(bundle, resource)), `Missing Pi resource: ${resource}`);
}
const loaded = await discoverAndLoadExtensions(
  manifest.pi.extensions.map((path) => join(bundle, path)), process.cwd(), process.env.PI_CODING_AGENT_DIR,
);
assert.deepEqual(loaded.errors, [], 'Every extension must load in the pinned Pi runtime');
const allNames = loaded.extensions.flatMap((ext) => [...ext.tools.keys()]);
assert.equal(new Set(allNames).size, allNames.length, 'No conflicting tool names');
const commands = loaded.extensions.flatMap((ext) => [...ext.commands.keys()]);
assert.equal(new Set(commands).size, commands.length, 'No conflicting command names');
const skills = manifest.pi.skills.flatMap((path) => {
  const found = loadSkillsFromDir({ dir: join(bundle, path), source: 'integration-test' });
  assert.deepEqual(found.diagnostics, [], `Skill diagnostics: ${path}`);
  return found.skills;
});
assert.equal(new Set(skills.map((s) => s.name)).size, skills.length, 'No conflicting skills');
assert.equal(skills.find((s) => s.name === 'i-have-adhd')?.disableModelInvocation, true);
assert.ok(skills.some((s) => s.name === 'ponytail'));
for (const name of ['subagent', 'lsp_diagnostics', 'fetch_content', 'get_search_content']) {
  assert.ok(allNames.includes(name), `Missing ${name}`);
}
assert.ok(!allNames.includes('web_search'));
assert.ok(!allNames.includes('source_check'));
const extension = (part) => loaded.extensions.find((ext) => ext.path.includes(part));
const plan = extension('/pi-plan/');
const lsp = extension('/pi-lsp-extension/');
assert.ok(plan.commands.has('plan'));
const invoke = async (ext, event, input, ctx) => {
  const results = [];
  for (const handler of ext.handlers.get(event) ?? []) results.push(await handler(input, ctx));
  return results;
};
let active = ['read', 'grep', 'find', 'ls', 'write', 'edit', 'bash', 'ask_user_question', ...allNames];
const original = [...active];
let branch = [];
let contextEntries = [];
let selectChoice;
let selectOptions;
const notices = [];
Object.assign(loaded.runtime, {
  getActiveTools: () => [...active],
  getAllTools: () => original.map((name) => ({ name })),
  setActiveTools: (names) => { active = [...names]; },
  appendEntry: (customType, data) => branch.push({ type: 'custom', customType, data }),
  sendMessage: (message) => contextEntries.push({ type: 'custom_message', ...message }),
  sendUserMessage: () => {},
});
const ctx = {
  cwd: process.cwd(), hasUI: true, mode: 'tui', isProjectTrusted: () => false,
  sessionManager: { getBranch: () => branch, buildContextEntries: () => contextEntries },
  ui: {
    theme: themeModule.theme, setStatus: () => {}, setWidget: () => {},
    notify: (text) => notices.push(text),
    select: async (_title, choices) => { selectOptions = choices; return selectChoice; },
  },
};
await invoke(plan, 'session_start', {}, ctx);
await plan.commands.get('plan').handler('', ctx);
assert.deepEqual(active, ['read', 'grep', 'find', 'ls', 'ask_user_question']);
for (const name of ['write', 'edit', 'bash', 'subagent', 'code_rewrite', 'codex_image', 'AskClaude']) {
  const result = await invoke(plan, 'tool_call', { toolName: name, input: { command: 'find . -delete' } }, ctx);
  assert.ok(result.some((r) => r?.block), `${name} must be blocked in plan mode`);
}
await plan.commands.get('plan').handler('', ctx);
assert.deepEqual(active, original, 'Leaving plan must restore extension tools');
await plan.commands.get('plan').handler('', ctx);
await invoke(plan, 'agent_end', {
  messages: [{ role: 'assistant', content: [{ type: 'text', text: 'Plan:\n1. Inspect files\n2. Report findings' }] }],
}, ctx);
assert.equal(selectOptions[0], 'Stay in plan mode');
selectChoice = 'Execute the plan';
await invoke(plan, 'agent_end', { messages: [] }, ctx);
assert.deepEqual(active, original);
await invoke(plan, 'turn_end', {
  message: { role: 'assistant', content: [{ type: 'text', text: '[DONE:1]' }] },
}, ctx); // Exercises the real theme API for completed steps.
await invoke(plan, 'turn_end', {
  message: { role: 'assistant', content: [{ type: 'text', text: '[DONE:2]' }] },
}, ctx);
await invoke(plan, 'agent_end', { messages: [] }, ctx);
assert.deepEqual(active, original);
loaded.runtime.flagValues.set('plan', true);
branch = [];
await invoke(plan, 'session_start', {}, ctx);
assert.ok(!active.includes('bash'));
loaded.runtime.flagValues.set('plan', false);
branch = [];
await invoke(plan, 'session_tree', {}, ctx);
assert.deepEqual(active, original, 'Tree navigation must restore branch-local plan state');
console.log('Pi loader, fetch-only registration and plan lifecycle/guards passed');

const jiti = createJiti(import.meta.url, { moduleCache: false });
const root = join(bundle, 'node_modules');
const { resolveHostPeerAliases } = await jiti.import(join(root, 'pi-subagents/src/runs/background/runner-aliases.ts'));
assert.deepEqual(resolveHostPeerAliases(piDir).missing, [], 'Detached subagents must resolve host SDK peers');
const settings = json(join(process.env.PI_CODING_AGENT_DIR, 'settings.json'));
assert.equal(settings.defaultProjectTrust, 'ask');
const subConfig = json(join(process.env.PI_CODING_AGENT_DIR, 'extensions/subagent/config.json'));
assert.equal(subConfig.globalConcurrencyLimit, 2);
assert.equal(subConfig.scheduledRuns.enabled, false);
assert.equal(subConfig.authorityPolicy.destructiveCleanup, 'confirm');
const { discoverAgents } = await jiti.import(join(root, 'pi-subagents/src/agents/agents.ts'));
const discovered = discoverAgents(process.cwd(), 'user', 'openai-codex');
for (const name of ['scout', 'reviewer', 'oracle', 'worker', 'researcher', 'evidence-auditor']) {
  const agent = discovered.agents.find((a) => a.name === name);
  assert.ok(agent, `Missing bundled role ${name}`);
  assert.equal(agent.inheritProjectContext, true);
  assert.equal(agent.inheritSkills, true);
  if (['scout', 'reviewer', 'oracle'].includes(name)) {
    assert.ok(!agent.tools.includes('bash') && !agent.tools.includes('write'));
  }
  if (name === 'researcher') assert.ok(agent.tools.includes('codex_search') && !agent.tools.includes('web_search'));
}
console.log('Subagent roles, settings and detached host-peer resolution passed');

// Exercise native style extensions through their registered Pi handlers.
const ponytail = extension('/ponytail/pi-extension/');
const adhd = extension('/i-have-adhd/extensions/');
const rtk = extension('/vendor/rtk.ts');
assert.ok(ponytail && adhd && rtk);
assert.ok(rtk.handlers.has('tool_call'), 'RTK probe must register the official hook');
branch = [];
contextEntries = [];
await invoke(ponytail, 'session_start', {}, ctx);
await invoke(adhd, 'session_start', {}, ctx);
const stylePrompt = async () => (await invoke(ponytail, 'before_agent_start', { systemPrompt: 'BASE' }, ctx))[0];
assert.match((await stylePrompt()).systemPrompt, /^BASE\n\nPONYTAIL MODE ACTIVE — level: full/);
assert.match(contextEntries.at(-1).content, /ADHD MODE ACTIVE/);
assert.ok(!contextEntries.at(-1).content.includes('disable-model-invocation:'), 'Do not inject skill frontmatter');
const firstCount = contextEntries.length;
await invoke(adhd, 'session_start', {}, ctx);
assert.equal(contextEntries.length, firstCount, 'Do not inject duplicate rules on reload');
await ponytail.commands.get('ponytail').handler('lite', ctx);
assert.match((await stylePrompt()).systemPrompt, /level: lite/);
await ponytail.commands.get('ponytail').handler('off', ctx);
assert.equal(await stylePrompt(), undefined);
await adhd.commands.get('i-have-adhd').handler('off', ctx);
assert.equal(contextEntries.at(-1).customType, 'i-have-adhd-disabled');
await invoke(adhd, 'session_start', {}, ctx);
assert.equal(contextEntries.at(-1).customType, 'i-have-adhd-disabled', 'Saved off wins over always-on');
branch = [];
contextEntries = [];
await invoke(ponytail, 'session_tree', {}, ctx);
await invoke(adhd, 'session_tree', {}, ctx);
assert.match((await stylePrompt()).systemPrompt, /level: full/);
assert.equal(contextEntries.at(-1).customType, 'i-have-adhd-rules');
contextEntries = []; // Compaction discarded the injected rules.
await invoke(adhd, 'session_compact', {}, ctx);
assert.equal(contextEntries.at(-1).customType, 'i-have-adhd-rules');
for (const ext of loaded.extensions.filter((ext) => ext === ponytail || ext === adhd)) {
  const results = await invoke(ext, 'input', { text: 'normal mode', source: 'interactive' }, ctx);
  if (results.some((r) => r?.action === 'handled')) break;
}
assert.equal(await stylePrompt(), undefined, 'Normal mode must turn off Ponytail before ADHD consumes input');
assert.equal(contextEntries.at(-1).customType, 'i-have-adhd-disabled');

// Rewrite only, never execute the rewritten test commands or contact providers.
const rewrite = async (command) => {
  const event = { toolName: 'bash', input: { command } };
  await invoke(rtk, 'tool_call', event, ctx);
  return event.input.command;
};
assert.equal(await rewrite('git status'), 'rtk git status');
assert.equal(await rewrite('rtk git status'), 'rtk git status');
for (const command of ['nix flake check', 'just check', 'tofu plan', 'sops --version', 'printf hello']) {
  assert.equal(await rewrite(command), command, `Pass through ${command}`);
}
process.env.RTK_DISABLED = '1';
assert.equal(await rewrite('git status'), 'git status');
delete process.env.RTK_DISABLED;
const config = spawnSync('rtk', ['config'], { encoding: 'utf8' });
assert.equal(config.status, 0, config.stderr);
assert.match(config.stdout, /\[tracking\]\nenabled = true/);
for (const section of ['tee', 'telemetry']) {
  assert.match(config.stdout, new RegExp(`\\[${section}\\]\\nenabled = false`));
}
const raw = spawnSync('rtk', ['proxy', 'sh', '-c', 'printf "raw output\\n"; exit 7'], { encoding: 'utf8' });
assert.equal(raw.stdout, 'raw output\n');
assert.equal(raw.status, 7, 'Raw bypass preserves failure status');
assert.ok(existsSync(join(process.env.HOME, '.local/share/rtk/history.db')), 'Operator-selected local statistics');
const gain = spawnSync('rtk', ['gain', '--format', 'json'], { encoding: 'utf8' });
assert.equal(gain.status, 0, gain.stderr);
assert.doesNotThrow(() => JSON.parse(gain.stdout));
assert.ok(!existsSync(join(process.env.HOME, '.local/share/rtk/tee')), 'No raw-output capture');
console.log('Ponytail/ADHD defaults, toggles, branch/compaction state and native RTK hook/privacy passed');

// Untrusted project config must not run an autoStart command or override a server.
writeFileSync('.pi-lsp.json', JSON.stringify({
  servers: { nix: { command: 'UNTRUSTED-SERVER-MUST-NOT-RUN' } }, autoStart: ['nix'],
}));
await invoke(lsp, 'session_start', {}, ctx);
await lsp.commands.get('lsp').handler('', ctx);
assert.ok(notices.at(-1).includes('nix: nil'));
assert.ok(!notices.at(-1).includes('UNTRUSTED'));
await invoke(lsp, 'session_shutdown', {}, ctx);
const { LspManager } = await jiti.import(join(root, 'pi-lsp-extension/src/lsp-manager.ts'));
const manager = new LspManager(process.cwd());
const samples = {
  'sample.nix': ['nix', 'let answer = 42; in answer\n'],
  'sample.py': ['python', 'answer: int = 42\n'],
  'sample.ts': ['typescript', 'const answer: number = 42;\n'],
  'sample.js': ['javascript', 'const answer = 42;\n'],
  'sample.c': ['c', 'int answer = 42;\n'],
  'sample.cpp': ['cpp', 'int answer = 42;\n'],
};
try {
  for (const [file, [language, text]] of Object.entries(samples)) {
    writeFileSync(file, text);
    assert.equal(manager.getLanguageId(file), language);
    await manager.getClientForFile(file); // Upstream deliberately starts asynchronously.
    const deadline = Date.now() + 30000;
    while (manager.isServerStarting(language) && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
    assert.ok(manager.getRunningClient(language)?.initialized, `${language}: native LSP initialize must succeed`);
  }
  for (const ext of ['cc', 'cxx', 'hpp', 'hxx', 'hh']) assert.equal(manager.getLanguageId(`sample.${ext}`), 'cpp');
} finally {
  await manager.shutdownAll();
}
console.log('Nix, Python, JavaScript, TypeScript, C and C++ native LSP initialization passed');
