// Offline checks against the actual Pi loader, the Nix-pinned local
// extensions and native RTK behavior. No real HOME, credentials, provider
// calls or model runs.
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

const [piDir, codexConfig, toolRepairConfig] = process.argv.slice(2);
const load = (path) => import(pathToFileURL(path).href);
const json = (path) => JSON.parse(readFileSync(path, 'utf8'));
const { discoverAndLoadExtensions } = await load(join(piDir, 'dist/index.js'));
// Managed settings must carry the exact pinned package set.
const settings = json(join(process.env.PI_CODING_AGENT_DIR, 'settings.json'));
assert.equal(settings.defaultProjectTrust, 'ask');
assert.equal(settings.defaultProvider, 'openai-codex');
assert.deepEqual(
  settings.packages.filter((spec) => spec.startsWith('npm:')),
  [
    'npm:@99percentpeople/pi-codex-api@0.4.0',
    'npm:@akepka/pi-cursor-cli-provider@0.10.1',
    'npm:@ayulab/pi-rewind@0.4.6',
    'npm:@juicesharp/rpiv-ask-user-question@2.9.0',
    'npm:pi-tool-repair@0.2.5',
  ],
  'Pinned npm specs must match the reviewed set',
);
for (const removed of [
  'pi-claude-bridge', 'pi-subagents', 'pi-web-access', 'pi-plan',
  'pi-lsp-extension', 'rpiv-todo', 'ponytail', 'i-have-adhd',
]) {
  assert.ok(!settings.packages.some((spec) => spec.includes(removed)), `${removed} must stay removed`);
}
const local = settings.packages.filter((spec) => !spec.startsWith('npm:'));
assert.equal(
  local.length, 3,
  'Exactly pi-review, the RTK hook and empty-args-retry are local entries',
);
for (const path of local) assert.ok(existsSync(path), `Missing local package: ${path}`);
const rtkHook = local.find((path) => path.endsWith('/hooks/pi/rtk.ts'));
const emptyArgsRetry = local.find((path) => path.endsWith('empty-args-retry.ts'));
assert.ok(emptyArgsRetry, 'empty-args-retry.ts must be pinned as a settings entry');
const piReview = local.find((path) => path !== rtkHook && path !== emptyArgsRetry);
json(codexConfig); // Generated extension config must stay valid JSON.
// Grammar recovery stays opt-in and scoped to GLM model ids only.
const toolRepair = json(toolRepairConfig);
assert.equal(toolRepair.grammarRepair.enabled, undefined, 'No global grammar repair');
assert.equal(toolRepair.grammarRepair.mode, 'recover');
assert.equal(toolRepair.grammarRepair.requireKnownTool, true);
assert.deepEqual(toolRepair.grammarRepair.grammars, ['glm']);
assert.deepEqual(toolRepair.grammarRepair.leakModels, ['glm']);
console.log('Settings pins and generated configs passed');

// Load the Nix-pinned extensions through Pi's actual loader.
const loaded = await discoverAndLoadExtensions(
  [rtkHook, join(piReview, 'review.ts'), emptyArgsRetry],
  process.cwd(), process.env.PI_CODING_AGENT_DIR,
);
assert.deepEqual(loaded.errors, [], 'Local extensions must load in the pinned Pi runtime');
const rtk = loaded.extensions.find((ext) => ext.path.endsWith('rtk.ts'));
const review = loaded.extensions.find((ext) => ext.path.includes('review'));
const emptyArgs = loaded.extensions.find((ext) => ext.path.endsWith('empty-args-retry.ts'));
assert.ok(
  emptyArgs?.handlers.has('message_end'),
  'empty-args-retry must register the official message_end handler',
);
assert.ok(rtk?.handlers.has('tool_call'), 'RTK hook must register the official tool_call handler');
assert.ok(review?.commands.has('review') && review.commands.has('end-review'), 'pi-review must register its commands');
console.log('Pi loader registration for pi-review and the RTK hook passed');

// Exercise empty-args-retry's pure transform: only schema-required tools with
// a completely absent/empty arguments payload flip the message into a
// retryable error, and every toolCall block is stripped so a retried turn
// never leaves unmatched calls in the history.
const { retryEmptyArguments } = await load(emptyArgsRetry);
const tools = [
  { name: 'edit', parameters: { type: 'object', required: ['path', 'edits'] } },
  { name: 'bash', parameters: { type: 'object', required: ['command'] } },
  { name: 'status', parameters: { type: 'object', required: [] } },
];
const assistant = (parts, stopReason = 'toolUse') => ({
  role: 'assistant', stopReason, content: parts,
});
const call = (name, arguments_) => ({ type: 'toolCall', id: 'call_x', name, arguments: arguments_ });
const toolCallsOf = (message) => message.content.filter((part) => part.type === 'toolCall');

const emptyEdit = retryEmptyArguments(assistant([call('edit', {})]), tools);
assert.ok(emptyEdit.changed, 'Empty edit arguments must convert the message');
assert.equal(emptyEdit.message.stopReason, 'error');
assert.equal(toolCallsOf(emptyEdit.message).length, 0, 'All toolCall blocks must be stripped');
assert.match(emptyEdit.message.errorMessage, /"edit".*path, edits/);
// Pi only auto-retries assistant errors whose text matches its
// RETRYABLE_PROVIDER_ERROR_PATTERN; keep the load-bearing phrasing pinned.
assert.match(
  emptyEdit.message.errorMessage,
  /^provider returned error/,
  'errorMessage must match Pi\'s retryable provider error pattern',
);

const missingArgs = retryEmptyArguments(
  assistant([call('edit', undefined)]), tools,
);
assert.ok(missingArgs.changed, 'Absent arguments must convert the message');

const mixed = retryEmptyArguments(
  assistant([call('write', { path: '/tmp/f', content: 'x' }), call('edit', {})]), tools,
);
assert.ok(mixed.changed, 'An empty call among valid calls must still convert');
assert.equal(toolCallsOf(mixed.message).length, 0, 'Even valid calls are stripped on retry');

const valid = retryEmptyArguments(
  assistant([call('edit', { path: '/tmp/f', edits: [{ oldText: 'a', newText: 'b' }] })]), tools,
);
assert.equal(valid.changed, false, 'Populated arguments must pass through unchanged');

for (const [label, message] of [
  ['unknown tool', assistant([call('fabric_exec', {})])],
  ['tool without required properties', assistant([call('status', {})])],
  ['non-toolUse stop reason', assistant([call('edit', {})], 'endTurn')],
]) {
  const result = retryEmptyArguments(message, tools);
  assert.equal(result.changed, false, `${label} must be left for Pi's own handling`);
}
console.log('empty-args-retry conversion behavior passed');

// Exercise the RTK hook: rewrite only, never execute the commands.
const ctx = { cwd: process.cwd(), hasUI: true, mode: 'tui' };
const rewrite = async (command) => {
  const event = { toolName: 'bash', input: { command } };
  for (const handler of rtk.handlers.get('tool_call')) await handler(event, ctx);
  return event.input.command;
};
assert.equal(await rewrite('git status'), 'git status', 'Preserve exact Git output');
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
console.log('Native RTK hook/privacy behavior passed');
