// Offline lifecycle regressions using the installed Pi loader/runner and SDK.
// Synthetic streams/children only; no credentials, model requests or Herdr socket.
import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { EventEmitter, once } from 'node:events';
import net from 'node:net';

const [piDir, bundle, bridgePath, herdrPath] = process.argv.slice(2);
const load = (path) => import(pathToFileURL(path).href);
const {
  createAgentSession, DefaultResourceLoader, ModelRuntime, SessionManager,
  SettingsManager, createEventBus, discoverAndLoadExtensions, loadSkillsFromDir,
} = await load(join(piDir, 'dist/index.js'));
const { ExtensionRunner } = await load(join(piDir, 'dist/core/extensions/runner.js'));
const { AssistantMessageEventStream } = await load(join(piDir, 'node_modules/@earendil-works/pi-ai/dist/utils/event-stream.js'));
const { createJiti } = await load(join(piDir, 'node_modules/jiti/lib/jiti.mjs'));
const theme = await load(join(piDir, 'dist/modes/interactive/theme/theme.js'));
theme.initTheme('dark', false);
const root = join(bundle, 'node_modules');
const tick = () => new Promise((resolve) => setImmediate(resolve));
const until = async (predicate, label) => {
  const deadline = Date.now() + 10000;
  while (!predicate() && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 10));
  assert.ok(predicate(), label);
};
const settingsManager = SettingsManager.inMemory({ compaction: { enabled: false }, retry: { enabled: false } });
const loaderOptions = {
  cwd: process.cwd(), agentDir: process.env.PI_CODING_AGENT_DIR, settingsManager,
  noExtensions: true, noSkills: true, noPromptTemplates: true, noThemes: true, noContextFiles: true,
};
const model = {
  id: 'offline-test', name: 'Offline test', provider: 'offline-test', api: 'openai-completions',
  baseUrl: '', reasoning: false, input: ['text'], contextWindow: 100000, maxTokens: 1000,
  cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
};
const modelRuntime = await ModelRuntime.create();
// Only the auth preflight is stubbed; the stream function below cannot use a provider.
modelRuntime.hasConfiguredAuth = () => true;
const errors = [];
const contexts = [];
const order = [];
let answer = 'Plan:\n1. Inspect files\n2. Report findings';
let chooseExecution = true;
const planLoader = new DefaultResourceLoader({
  ...loaderOptions,
  additionalExtensionPaths: [join(root, 'pi-plan/extensions/plan/index.ts')],
  extensionFactories: [(pi) => {
    for (const event of ['before_agent_start', 'agent_start', 'turn_start', 'turn_end', 'agent_end']) {
      pi.on(event, () => { order.push(event); });
    }
    pi.on('context', (event) => { order.push('context'); contexts.push(event.messages); });
  }],
});
await planLoader.reload();
assert.deepEqual(planLoader.getExtensions().errors, []);
const { session: planSession } = await createAgentSession({
  resourceLoader: planLoader, settingsManager, modelRuntime, model, sessionManager: SessionManager.inMemory(),
});
const fakeStream = () => {
  const stream = new AssistantMessageEventStream();
  const message = {
    role: 'assistant', content: [{ type: 'text', text: answer }], api: model.api,
    provider: model.provider, model: model.id, stopReason: 'stop', timestamp: Date.now(),
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } },
  };
  stream.push({ type: 'done', reason: 'stop', message });
  stream.end(message);
  return stream;
};
planSession.agent.streamFunction = fakeStream;
try {
  await planSession.bindExtensions({ mode: 'tui', onError: (error) => errors.push(error), uiContext: {
    theme: theme.theme, setStatus: () => {}, setWidget: () => {}, notify: () => {},
    select: async () => {
      if (!chooseExecution) return 'Stay in plan mode';
      chooseExecution = false;
      answer = 'Working on the plan';
      return 'Execute the plan';
    },
  } });
  await planSession.prompt('/plan');
  await planSession.prompt('Create a plan');
  await until(() => contexts.some((messages) => messages.some((m) => m.customType === 'pi-plan-execute')),
    'Initial execution must reach the actual agent context');
  await planSession.agent.waitForIdle();
  await tick();
  const initialExecution = contexts.find((messages) => messages.some((m) => m.customType === 'pi-plan-execute'));
  assert.match(initialExecution.find((m) => m.customType === 'pi-plan-execute').content, /\[DONE:n\]/);
  assert.ok(!initialExecution.some((m) => m.customType === 'pi-plan-context'));
  order.length = 0;
  await planSession.prompt('Continue the approved plan');
  const execution = contexts.at(-1).find((m) => m.customType === 'pi-plan-execution-context');
  assert.match(execution.content, /EXECUTING PLAN/);
  assert.match(execution.content, /Remaining steps:[\s\S]*1\. Inspect files[\s\S]*2\. Report findings/);
  assert.match(execution.content, /\[DONE:n\]/);
  assert.deepEqual(order, ['before_agent_start', 'agent_start', 'turn_start', 'context', 'turn_end', 'agent_end']);
  answer = '[DONE:1] [DONE:2]';
  await planSession.prompt('Finish');
  assert.ok(planSession.messages.some((m) => m.customType === 'pi-plan-complete'));
  answer = 'Ordinary answer';
  await planSession.prompt('Unrelated question after plan completion');
  assert.ok(!contexts.at(-1).some((m) => m.customType === 'pi-plan-execution-context'),
    'Completed execution reminders must not reach later normal requests');
  await planSession.prompt('/plan');
  await planSession.prompt('Explore a different task');
  assert.ok(contexts.at(-1).some((m) => m.customType === 'pi-plan-context'));
  assert.ok(!contexts.at(-1).some((m) => m.customType === 'pi-plan-execution-context'),
    'Old execution reminders must not reach planning requests');
  await planSession.prompt('/plan');
  assert.deepEqual(errors, []);
} finally {
  planSession.dispose();
}
console.log('6: Native Pi plan creation → execution → context → completion ordering passed');

// Both Ponytail alias branches must reach native skill expansion, not literal text.
const ponySkills = loadSkillsFromDir({ dir: join(root, '@dietrichgebert/ponytail/skills'), source: 'test' });
assert.deepEqual(ponySkills.diagnostics, []);
const ponyLoader = new DefaultResourceLoader({
  ...loaderOptions,
  additionalExtensionPaths: [join(root, '@dietrichgebert/ponytail/pi-extension/index.js')],
  skillsOverride: () => ponySkills,
});
await ponyLoader.reload();
const { session: ponySession, extensionsResult: ponyLoaded } = await createAgentSession({
  resourceLoader: ponyLoader, settingsManager, modelRuntime, model, sessionManager: SessionManager.inMemory(),
});
ponySession.agent.streamFunction = fakeStream;
let heldStream;
try {
  await ponySession.bindExtensions({ mode: 'print', onError: (error) => errors.push(error) });
  const aliases = ponyLoaded.extensions[0].commands;
  for (const idle of [true, false]) {
    let heldRun;
    if (!idle) {
      heldStream = new AssistantMessageEventStream();
      ponySession.agent.streamFunction = () => heldStream;
      heldRun = ponySession.prompt('Hold a synthetic turn for queued aliases');
      await until(() => ponySession.isStreaming, 'Synthetic run is active');
    }
    for (const name of ['ponytail-review', 'ponytail-audit', 'ponytail-gain', 'ponytail-debt', 'ponytail-help']) {
      // Capture the void extension API's promise so the test waits for the real SDK path.
      let sent;
      ponyLoaded.runtime.sendUserMessage = (text, options) => { sent = ponySession.sendUserMessage(text, options); };
      await aliases.get(name).handler('', { isIdle: () => idle });
      await sent;
      const message = idle ? ponySession.messages.findLast((m) => m.role === 'user')
        : ponySession.agent.followUpQueue.messages.at(-1);
      assert.match(message.content[0].text, new RegExp(`<skill name="${name}"`));
      assert.ok(!message.content[0].text.startsWith('/skill:'));
      ponySession.clearQueue();
    }
    if (heldStream) {
      const message = await fakeStream().result();
      heldStream.push({ type: 'done', reason: 'stop', message });
      heldStream.end(message);
      await heldRun;
      heldStream = undefined;
    }
  }
  assert.deepEqual(errors, []);
} finally {
  if (heldStream) {
    const message = await fakeStream().result();
    heldStream.push({ type: 'done', reason: 'stop', message });
    heldStream.end(message);
  }
  await ponySession.abort();
  ponySession.dispose();
}
console.log('8: All five Ponytail aliases expand through native Pi, idle and queued');

// Load the actual unmodified Herdr hook, replacing transport with an in-memory
// socket double BEFORE loading. No attempt can reach any filesystem socket.
const savedEnv = Object.fromEntries(['HERDR_ENV', 'HERDR_SOCKET_PATH', 'HERDR_PANE_ID'].map((key) => [key, process.env[key]]));
const connect = net.createConnection;
const reports = [];
net.createConnection = () => {
  const socket = new EventEmitter();
  socket.destroy = () => {};
  socket.write = (text) => {
    reports.push(JSON.parse(text));
    queueMicrotask(() => socket.emit('data', Buffer.from('{}')));
  };
  queueMicrotask(() => socket.emit('connect'));
  return socket;
};
Object.assign(process.env, { HERDR_ENV: '1', HERDR_SOCKET_PATH: '/synthetic-no-socket', HERDR_PANE_ID: 'synthetic-pane' });
try {
  for (const mode of ['tui', 'rpc', 'json', 'print']) {
    reports.length = 0;
    const eventBus = createEventBus();
    const loaded = await discoverAndLoadExtensions([herdrPath, bridgePath], process.cwd(), process.env.PI_CODING_AGENT_DIR, eventBus);
    assert.deepEqual(loaded.errors, []);
    const runner = new ExtensionRunner(loaded.extensions, loaded.runtime, process.cwd(), SessionManager.inMemory(), {});
    runner.onError((error) => errors.push(error));
    const pending = [];
    runner.setUIContext({ select: () => new Promise((resolve) => pending.push(resolve)),
      input: () => new Promise((resolve) => pending.push(resolve)),
      custom: (factory) => factory() }, mode);
    const ui = runner.getUIContext();
    const state = () => reports.filter((r) => r.method === 'pane.report_agent').at(-1)?.params.state;
    // A child/unstarted runner must not report its parent's pane.
    const unstarted = ui.select('Unstarted');
    pending.shift()(undefined);
    await unstarted;
    await tick();
    assert.equal(reports.length, 0);
    await runner.emit({ type: 'session_start', reason: 'startup' });
    await runner.emit({ type: 'agent_start' });
    await tick();
    assert.equal(state(), mode === 'tui' ? 'working' : undefined);
    eventBus.emit('herdr:blocked', { active: true, label: 'Independent blocker' });
    const first = ui.select('First prompt');
    const nested = ui.custom(() => ui.input('Nested prompt'));
    await tick();
    assert.equal(state(), mode === 'tui' ? 'blocked' : undefined);
    pending.shift()(undefined);
    await first;
    await tick();
    assert.equal(state(), mode === 'tui' ? 'blocked' : undefined, 'Overlapping prompt remains blocked');
    eventBus.emit('herdr:blocked', { active: false });
    await tick();
    assert.equal(state(), mode === 'tui' ? 'blocked' : undefined, 'Native span owns a separate blocker');
    pending.shift()(undefined);
    await nested;
    await tick();
    assert.equal(state(), mode === 'tui' ? 'working' : undefined);
    await runner.emit({ type: 'agent_settled' });
    const idlePrompt = ui.select('Idle prompt');
    await tick();
    assert.equal(state(), mode === 'tui' ? 'blocked' : undefined);
    pending.shift()(undefined);
    await idlePrompt;
    await tick();
    assert.equal(state(), mode === 'tui' ? 'idle' : undefined);
    const closing = ui.select('Shutdown during prompt');
    await tick();
    await runner.emit({ type: 'session_shutdown', reason: 'quit' });
    pending.shift()(undefined);
    await closing;
    await tick();
    assert.equal(state(), mode === 'tui' ? 'idle' : undefined);
    if (mode !== 'tui') assert.equal(reports.length, 0, 'Headless children never report a pane');
    eventBus.clear();
  }
} finally {
  net.createConnection = connect;
  for (const [key, value] of Object.entries(savedEnv)) {
    if (value === undefined) delete process.env[key]; else process.env[key] = value;
  }
}
assert.deepEqual(errors, []);
console.log('7: Native overlapping/nested/idle prompts share Herdr counted blockers; unstarted/headless safe');

const jiti = createJiti(import.meta.url, { moduleCache: true });
const { LspManager } = await jiti.import(join(root, 'pi-lsp-extension/src/lsp-manager.ts'));
const { LspClient } = await jiti.import(join(root, 'pi-lsp-extension/src/lsp-client.ts'));
const serverPath = join(process.cwd(), 'synthetic-lsp.cjs');
writeFileSync(serverPath, `
const requireLsp = require('node:module').createRequire(${JSON.stringify(join(root, 'pi-lsp-extension/package.json'))});
const { createMessageConnection, StreamMessageReader, StreamMessageWriter } = requireLsp('vscode-languageserver-protocol/node');
const connection = createMessageConnection(new StreamMessageReader(process.stdin), new StreamMessageWriter(process.stdout));
const mode = process.argv[2];
process.on('SIGTERM', () => {});
setInterval(() => {}, 1000);
connection.onRequest('initialize', () => {
  process.stderr.write('INITIALIZING\\n');
  return mode === 'pending' ? new Promise(() => {}) : { capabilities: {} };
});
connection.onRequest('shutdown', () => {
  if (mode === 'reject') throw new Error('synthetic shutdown rejection');
  return mode === 'hang' ? new Promise(() => {}) : null;
});
connection.onNotification('exit', () => { if (mode === 'cooperative') process.exit(0); });
connection.listen();
`);
const config = (mode) => ({ command: process.execPath, args: [serverPath, mode] });
// Cancellation between spawn() and its asynchronous spawn event must not
// dereference this.process after shutdown has cleared it.
const spawning = new LspClient({ ...config('stubborn'), languageId: 'synthetic', rootDir: process.cwd() });
const spawnStart = spawning.start();
const spawnRejected = assert.rejects(spawnStart, /shut down during spawn/);
const spawningChild = spawning.process;
const spawnExit = once(spawningChild, 'exit');
await spawning.shutdown();
await spawnRejected;
await spawnExit;
const missing = new LspClient({ command: './missing-synthetic-server', args: [], languageId: 'synthetic', rootDir: process.cwd() });
await assert.rejects(missing.start(), /Failed to spawn LSP server/);
await missing.shutdown();
const socketClient = new LspClient({ ...config('stubborn'), languageId: 'synthetic', rootDir: process.cwd(),
  socketPath: join(process.cwd(), 'missing-synthetic-lsp.sock') });
const socketStart = assert.rejects(socketClient.start(), /socket closed|Failed to connect/);
await socketClient.shutdown();
await socketStart;
assert.equal(socketClient.socket, null);
assert.equal(socketClient.initialized, false);

const managerErrors = [];
const ready = [];
const callbacks = { onServerReady: (language) => ready.push(language), onServerError: (_language, error) => managerErrors.push(error) };
const pendingManager = new LspManager(process.cwd(), { nix: config('pending') }, callbacks);
let pendingChild;
try {
  await pendingManager.getClientForLanguage('nix');
  await until(() => pendingManager.pendingClients.size === 1, 'Pending client must be owned before startup completes');
  const pendingClient = [...pendingManager.pendingClients][0];
  pendingChild = pendingClient.process;
  const pendingExit = once(pendingChild, 'exit');
  // Ensure the synthetic child has installed its signal handler and received initialize.
  let initializing = false;
  pendingChild.stderr.on('data', (data) => { if (data.toString().includes('INITIALIZING')) initializing = true; });
  await until(() => initializing, 'Synthetic server is waiting in initialize');
  const startupRejected = assert.rejects(pendingManager.startingServers.get('nix'), /Failed to start LSP/);
  await pendingManager.shutdownAll();
  await startupRejected;
  assert.equal(pendingClient.disposed, true);
  assert.equal(pendingManager.getRunningClient('nix'), null);
  assert.deepEqual(ready, []);
  assert.equal(await pendingManager.getClientForLanguage('nix'), null);
  pendingManager.startEagerly(['nix']);
  await assert.rejects(pendingManager.restartServer('nix'), /shutting down/);
  assert.deepEqual(await pendingExit, [null, 'SIGKILL']);
} finally {
  await pendingManager.shutdownAll();
  if (pendingChild && pendingChild.exitCode === null && pendingChild.signalCode === null) pendingChild.kill('SIGKILL');
}

// Deterministically force an already-successful handshake continuation to arrive
// after shutdown; disposal alone must not permit publication of that client.
const lateManager = new LspManager(process.cwd(), undefined, callbacks);
let finishStart;
const lateClient = { start: () => new Promise((resolve) => { finishStart = resolve; }),
  shutdown: async function () { this.disposed = true; }, disposed: false };
const lateStart = lateManager.startClient('nix', lateClient);
const lateRejected = assert.rejects(lateStart, /startup failed/);
await lateManager.shutdownAll();
finishStart();
await lateRejected;
assert.equal(lateClient.disposed, true);
assert.equal(lateManager.getRunningClient('nix'), null);
assert.deepEqual(ready, []);

let finishWorkspace;
let starts = 0;
const workspace = { stateDir: null, getWorkspaceFolders: () => [], shutdown: () => {},
  ensureReady: () => new Promise((resolve) => { finishWorkspace = resolve; }) };
const workspaceManager = new LspManager(process.cwd(), { nix: config('pending') },
  { ...callbacks, onServerStart: () => starts++ }, 'synthetic', workspace);
await workspaceManager.getClientForLanguage('nix');
const workspaceRejected = assert.rejects(workspaceManager.startingServers.get('nix'), /shutting down/);
await workspaceManager.shutdownAll();
finishWorkspace(true);
await workspaceRejected;
assert.equal(starts, 0, 'Workspace completion after shutdown must not launch a server');

// An explicit restart can overlap a lazy same-language start. Failure owns only
// its own client, never a different client that already published successfully.
const overlapManager = new LspManager(process.cwd());
let rejectOverlap;
const liveClient = { start: async () => {}, initialized: true, disposed: false,
  shutdown: async function () { this.disposed = true; } };
const failedClient = { start: () => new Promise((_resolve, reject) => { rejectOverlap = reject; }),
  shutdown: async function () { this.disposed = true; }, disposed: false };
try {
  const failedStart = overlapManager.startClient('nix', failedClient);
  const failure = assert.rejects(failedStart, /synthetic overlapping startup rejection/);
  await overlapManager.startClient('nix', liveClient);
  rejectOverlap(new Error('synthetic overlapping startup rejection'));
  await failure;
  assert.equal(failedClient.disposed, true);
  assert.equal(overlapManager.getRunningClient('nix'), liveClient,
    'Failed startup must retain another published client');
} finally {
  await overlapManager.shutdownAll();
}
assert.equal(liveClient.disposed, true, 'Manager must still own the successful client at shutdown');

// Unexpected disposal failures must be reported only after every client has
// had its cleanup attempted, rather than being swallowed by shutdownAll.
const failedManager = new LspManager(process.cwd());
const disposeError = new Error('synthetic dispose failure');
let otherDisposed = false;
failedManager.clients.set('one', { shutdown: async () => { throw disposeError; } });
failedManager.clients.set('two', { shutdown: async () => { otherDisposed = true; } });
await assert.rejects(failedManager.shutdownAll(), (error) =>
  error instanceof AggregateError && error.errors[0] === disposeError);
assert.equal(otherDisposed, true);
console.log('9: Pending initialize, late publication and delayed workspace shutdown races passed');

const shutdownMessages = [];
const consoleError = console.error;
console.error = (...args) => shutdownMessages.push(args.join(' '));
try {
  for (const mode of ['stubborn', 'reject', 'hang', 'notification-reject', 'cooperative']) {
    const client = new LspClient({ ...config(mode), languageId: 'synthetic', rootDir: process.cwd() });
    let child;
    try {
      await client.start();
      child = client.process;
      const exited = once(child, 'exit');
      const signals = [];
      const kill = child.kill.bind(child);
      child.kill = (signal) => { signals.push(signal); return kill(signal); };
      if (mode === 'notification-reject') {
        // A locally rejected exit write (closed transport) is a teardown boundary.
        client.connection.sendNotification = async () => { throw new Error('synthetic exit write rejection'); };
      }
      await client.shutdown();
      assert.equal(client.process, null);
      assert.equal(client.disposed, true);
      assert.equal(client.initialized, false);
      await client.shutdown(); // idempotent; no second escalation
      const [code, signal] = await exited;
      if (mode === 'cooperative') {
        assert.equal(code, 0);
        await new Promise((resolve) => setTimeout(resolve, 2100));
        assert.ok(!signals.includes('SIGKILL'), 'Confirmed exit must cancel escalation');
      } else {
        assert.equal(signal, 'SIGKILL', `${mode}: ignore killed flag after SIGTERM`);
        assert.deepEqual(signals, ['SIGTERM', 'SIGKILL']);
      }
    } finally {
      // Test-owned process cleanup even when an assertion fails; never target a host process.
      if (child && child.exitCode === null && child.signalCode === null) child.kill('SIGKILL');
      await client.shutdown();
    }
  }
} finally {
  console.error = consoleError;
}
for (const message of ['synthetic shutdown rejection', 'Shutdown request timed out', 'synthetic exit write rejection']) {
  assert.ok(shutdownMessages.some((line) => line.includes(message)), `Teardown reports ${message}`);
}
console.log('10: Stubborn children escalate, confirmed exits cancel, shutdown request/exit-write rejections are contained');
