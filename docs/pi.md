# Pi extensions

ThinkPad's native Home Manager configuration lives in `modules/desktop/agents.nix`. The extension set is declared directly in Pi's managed `settings.packages`: pinned `npm:` specs for published packages plus three immutable Nix store entries (hash-pinned `pi-review`, the official RTK hook and the repository's `empty-args-retry.ts`). No vendored `package.json`, npm lock, patch set or Nix npm build exists anymore. Changes require a separately authorized system/Home Manager activation and a **new Pi session** afterward. This work does not activate or reload a running session. Do not overwrite managed settings using `pi install`, `/curator` or settings-writing commands; change the declaration instead. Credentials, sessions, trust decisions, artifacts and Pi's installed package trees remain private mutable home state.

Bastion's temporary [administration workspace](reinstall.md#bastions-temporary-administration-workspace) uses its own stable Pi package directly with the existing `marcos` account, **not** this Home Manager extension configuration. No credentials or newer desktop settings are copied; provider/extension compatibility is a separate runtime check.

## Package management

Versioned `npm:` specs are pinned and skipped by `pi update`; Pi installs them into mutable `~/.pi/agent/npm` (running `npm install` itself) on the first start after they are missing, which needs network access. `pi-review` stays a fixed-revision, fixed-hash `fetchFromGitHub` store path, the RTK hook loads straight from the pinned Nixpkgs source, and `empty-args-retry.ts` is copied from the repository into its own store path. The Home Manager settings file is read-only, so package identity can only change through the declaration. `nodejs` stays in Pi's wrapper PATH because Pi shells out to npm for these installs.

## Enabled additions

| Package | Pin | Configuration / use |
|---|---|---|
| `@99percentpeople/pi-codex-api` | 0.4.0 | Codex search/quota/image tools; `~/.pi/agent/99extensions.json` keeps `gpt-image-2`, quota status; `allowOtherProviders` |
| `@akepka/pi-cursor-cli-provider` | 0.10.1 | Cursor provider; resolves its CLI through `CURSOR_AGENT_PATH` |
| `@ayulab/pi-rewind` | 0.4.6 | `ayu.rewind.restoreOnTree = "ask"`; checkpoint restore never automatic on resume/fork/clone |
| `@juicesharp/rpiv-ask-user-question` | 2.9.0 | `~/.config/rpiv-ask-user-question/config.json`: collapse key `ctrl+]` |
| `pi-tool-repair` | 0.2.5 | Repairs malformed tool-call arguments (stringified `edits` arrays, field aliases, null optionals) before Pi validation — covers the `edit` failures seen from z.ai GLM models. `~/.pi/agent/extensions/pi-tool-repair.json` keeps grammar recovery opt-in per model id (`leakModels: ["glm"]`, `recover` mode, known-tool gated); default argument repairs need no config |
| `pi-review` | commit `f1de050504936046c0f85b21fec0e0a93ef394eb` (Nix hash pin) | `/review`, `/end-review` |
| RTK | Nixpkgs 0.47.0 | Native CLI plus its matching official Pi hook, not another npm wrapper |
| `empty-args-retry.ts` | Repository source / Nix store path; Pi 0.85.1 contract | Converts empty-argument calls for active tools with required schema properties into a transient provider error; uses Pi's bounded agent retry, not argument repair |

Pi's declarative defaults use `openai-codex/gpt-6-astra` with thinking level **high**. This is a setting change only; it does not activate or reload a running session.

Use existing `codex_search` for search/navigation. The former direct-URL `fetch_content`/`get_search_content` tools were provided by `pi-web-access`, which is removed (below).

## Removed by operator decision

The following were removed together with the npm manifest/lock build that carried them; none of their commands, tools, skills, configs or patches remain:

- `pi-subagents` (and the `subagents` settings block, role overrides, `~/.pi/agent/extensions/subagent/config.json`): no subagent/workflow tooling.
- `pi-web-access` (and both generated `web-search.json` policy files): no `fetch_content`/`get_search_content` tools.
- `pi-plan` (and its patch): no plan mode.
- `pi-lsp-extension` (and its patch): no LSP tools; the `nil`/`pyright`/`typescript-language-server`/`clang-tools` servers left Pi's wrapper PATH with it.
- `@dietrichgebert/ponytail` (and its patch plus `~/.config/ponytail/config.json`).
- `i-have-adhd` (vendored skill/extension plus `~/.pi/agent/i-have-adhd.json`).
- `@juicesharp/rpiv-todo` (plus `~/.config/rpiv-todo/config.json`).
- `pi-claude-bridge` (plus `~/.pi/agent/claude-bridge.json` and the `claude-code` unfree allowance/package): no `AskClaude` tool and no Claude provider through Pi. Upstream 0.7.0 (latest) hardcodes Claude-native `settingSources: ["user", "project"]` for AskClaude with no config override, so the former build-time adaptation could not be carried into a pi-managed install; the operator chose removal over retaining a Nix-patched package.
- The two vendored Herdr Pi extensions (`~/.pi/agent/extensions/herdr-agent-state.ts` and `herdr-ui-prompts.ts`): Pi no longer reports session/prompt state to Herdr panes. The Herdr program itself is unchanged.

Removals are declarative history: `git log`/`git show` on this file recover the exact prior pins, patches and configuration if any capability is wanted again.

## Empty-argument retries

The local extension handles a class `pi-tool-repair` cannot reconstruct: missing, empty or non-object arguments for an active tool declaring required properties. At `message_end`, it converts the whole assistant `toolUse` response to an error and removes **every** tool-call block, including valid siblings, so none is executed or left unmatched by that discarded response. Populated argument objects, unknown/inactive tools, tools without required properties and non-`toolUse` responses are left to Pi's normal handling. It is model-agnostic, not restricted by the separate GLM grammar-repair configuration.

Automatic continuation depends on `retry.enabled` and `retry.maxRetries` (Pi 0.85.1 defaults: enabled, at most **three retries** after the initial failure, with 2/4/8-second backoff). Disabled or exhausted retry leaves an error, not repaired arguments. The `provider returned error` phrasing must remain recognized by Pi's actual retry classifier. On Pi upgrades, recheck that classifier and message replacement/persistence ordering; see [pinned retry-contract research](research.md#pi-empty-argument-retry-contract--2026-09-12). Offline tests do not establish a provider-side fix or live-session acceptance.

## RTK

`rtk` is available in the home profile and Pi wrapper. Its official hook delegates supported **bash** rewrites to the same pinned binary with a two-second timeout; missing/unsupported rewrites pass through. Existing read/grep tools are unchanged. Config at `~/.config/rtk/config.toml` excludes infrastructure/credential command families (`nix`, `nixos-rebuild`, `just`, `deploy`, `disko`, `tofu`, `terraform`, `ssh`, `sops`, `age`) from automatic compression. This is not an authorization policy: these commands still require their normal review.

- `rtk gain` or `rtk gain --format json`: local token statistics, **not** subscription quota.
- `rtk proxy COMMAND ...`: run without filtering; the offline test checks raw stdout and a failing exit status.
- `RTK_DISABLED=1 pi`: disable automatic rewriting for a session. An explicitly requested `rtk ...` command remains explicit.
- Do not run `rtk init`: Home Manager already supplies the hook/config. Do not install a second `pi-rtk`/token-killer wrapper.

**Privacy choice:** telemetry and full raw-output tee capture are disabled; `RTK_TELEMETRY_DISABLED=1` is also declared for the home session. The operator chose stock **local usage statistics** after testing found that RTK 0.47 ignores `tracking.enabled` and `history_days` overrides. Keep its actual enabled/90-day defaults; do not claim tracking can be disabled merely by editing that table. Its private `~/.local/share/rtk/history.db` contains command text, timing, paths and token counts; parse-failure records can include error messages. Never put passwords/tokens in command arguments. Existing home persistence covers this mutable state; nothing is committed or moved to the Nix store. RTK's output is lossy: use a raw rerun when details matter, especially before acting on a filtered diff or failure. No percentage-savings claim was measured against a real workload here.

## Validation

`checks.x86_64-linux.pi-extensions` is part of `devenv tasks run repo:check-full`. In a sandbox with an empty HOME and no credentials it loads the managed settings through **Pi 0.85.1's actual loader**, asserts the exact pinned `npm:` spec set and the absence of every removed package, verifies all three local store entries exist and the generated `99extensions.json`/pi-tool-repair configs stay valid and correctly scoped, loads `pi-review`, the RTK hook and `empty-args-retry.ts` through the real loader (command/handler registration), and exercises native RTK rewrite/config/statistics/raw-bypass privacy behavior. The retry transform tests cover empty/missing arguments, stripping all sibling calls and valid/unknown/no-required/non-toolUse pass-through; retryability is checked with **the packaged Pi dependency's `isRetryableAssistantError`**, including non-error, unrecognized-error and quota-exhaustion rejection, not a copied prefix regex. It cannot load the `npm:` packages themselves (offline sandbox, mutable install tree), so their runtime behavior is not covered by checks; a new Pi session after activation is the real acceptance step. It makes no model request and activates no host.
