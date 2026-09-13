import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const [codexConfig] = process.argv.slice(2);
const json = (path) => JSON.parse(readFileSync(path, 'utf8'));
const settings = json(join(process.env.PI_CODING_AGENT_DIR, 'settings.json'));
assert.equal(settings.defaultProjectTrust, 'ask');
assert.equal(settings.defaultProvider, 'openai-codex');
assert.equal(settings.defaultModel, 'gpt-6-astra');
assert.equal(settings.defaultThinkingLevel, 'high');
assert.equal(settings.ayu, undefined, 'Rewind/checkpoint settings must be removed');
assert.deepEqual(
  settings.packages,
  [
    'npm:@99percentpeople/pi-codex-api@0.4.0',
    'npm:@akepka/pi-cursor-cli-provider@0.10.1',
    'npm:@dietrichgebert/ponytail@4.9.0',
    'npm:@juicesharp/rpiv-ask-user-question@2.9.0',
  ],
  'Exactly the reviewed npm pins, with no removed packages or local extensions',
);
const codex = json(codexConfig);
assert.equal(codex['codex-api'].imageModel, 'gpt-image-2');
assert.equal(codex['codex-api'].usageStatus, true);
console.log('Pi settings pins, removed-extension absence and generated Codex config passed; npm packages not installed or loaded');
