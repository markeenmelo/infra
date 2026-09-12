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
assert.equal(local.length, 2, 'Exactly pi-review and the RTK hook are local entries');
for (const path of local) assert.ok(existsSync(path), `Missing local package: ${path}`);
const rtkHook = local.find((path) => path.endsWith('/hooks/pi/rtk.ts'));
const piReview = local.find((path) => path !== rtkHook);
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
  [rtkHook, join(piReview, 'review.ts')], process.cwd(), process.env.PI_CODING_AGENT_DIR,
);
assert.deepEqual(loaded.errors, [], 'Local extensions must load in the pinned Pi runtime');
const rtk = loaded.extensions.find((ext) => ext.path.endsWith('rtk.ts'));
const review = loaded.extensions.find((ext) => ext.path.includes('review'));
assert.ok(rtk?.handlers.has('tool_call'), 'RTK hook must register the official tool_call handler');
assert.ok(review?.commands.has('review') && review.commands.has('end-review'), 'pi-review must register its commands');
console.log('Pi loader registration for pi-review and the RTK hook passed');

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
