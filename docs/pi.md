# Pi extensions

ThinkPad's native Home Manager configuration lives in `modules/desktop/agents.nix`; npm versions/integrities live in `modules/desktop/assets/pi-extensions/{package.json,package-lock.json}`. No other host gets this bundle. Changes require a separately authorized system/Home Manager activation and a **new Pi session** afterward. This work does not activate or reload a running session. Do not overwrite managed settings using `pi install`, `/curator`, or subagent settings-writing commands; change the declaration instead. Credentials, sessions, trust decisions and artifacts remain private mutable home state.

## Enabled additions

| Package | Pin | Configuration / use |
|---|---|---|
| `pi-subagents` | 0.67.0 | `/subagents-doctor`, `/subagents-models`, `/subagents-fleet`; ask Pi to use scout, reviewer, worker or oracle |
| `pi-lsp-extension` | 1.3.0 | Lazy language servers; `/lsp` reports status, `/lsp-restart LANGUAGE` restarts one |
| `pi-plan` | 0.1.1 | `/plan`, `/plan:status`, Ctrl+Alt+P, or `pi --plan`; shell-free exploration, explicit execution choice |
| `pi-web-access` | 0.29.0 | **Only** `fetch_content` and `get_search_content`; direct public pages/images and local PDF text extraction |
| `@dietrichgebert/ponytail` | 4.9.0 | **Full** by operator choice; `/ponytail lite\|full\|ultra\|off`, `/ponytail status`; quiet startup, visible mode indicator |
| `i-have-adhd` | 0.3.0, commit `6f1f982d0a47c65899af3c5a7450b7098bc65325` | Native Pi extension and skill; **always on** by operator choice; `/i-have-adhd on\|off` |
| RTK | Nixpkgs 0.47.0 | Native CLI plus its matching official Pi hook, not another npm wrapper |

Pi's declarative defaults use `openai-codex/gpt-6-astra` with thinking level **high**. This is a setting change only; it does not activate or reload a running session.

The requested `pi-web-acces` is not a published package; the corrected name is above. At the operator's choice, **omit `@specode/pi-subscription-usage`**: existing `@99percentpeople/pi-codex-api` 0.4.0 already supplies Codex quota status, `/codex-usage`, and confirmed `/codex-redeem`. Specode 1.0.2 additionally supports OpenCode Go, Grok and Kimi, not Claude/Cursor quota. It adds no web access. Keep one Codex background monitor.

Use existing `codex_search` for search/navigation and `fetch_content` for direct public URLs. Disable the second package's search/source-check commands/tools, browser-cookie extraction, GitHub cloning/private-CLI access, remote hosted extraction, YouTube/local-video upload, curator and automatic browser opening. PDFs use local `unpdf`, not Datalab/Gemini. SSRF checks remain enabled. Both `~/.pi/agent/web-search.json` and `$XDG_CONFIG_HOME/pi/web-search.json` carry the same generated policy because upstream chooses between them according to the environment. Explicit answer-mode fetching can still use the active model; fetched content is untrusted, not instructions.

## Ponytail and ADHD-friendly output

Ponytail prefers the existing code/standard library and the smallest working change. Its review/audit/debt/gain/help skills remain available; commands do not replace repository safety or required tests. ADHD mode requests action-first, structured output; its `/skill:i-have-adhd` alias enables the same session-persistent mode without duplicating instructions. Neither mode is a medical assessment. Explicit requests for full explanations and repository safety procedures still take priority over terse-output/minimal-code preferences.

Defaults are declarative at `~/.config/ponytail/config.json` and `~/.pi/agent/i-have-adhd.json`; use per-session commands rather than `/ponytail default`, which tries to overwrite the managed file. Saved session choices win over defaults. Ponytail restores branch-local choices (including tree navigation via the patch); ADHD restores choices and reinjects rules after compaction removes them. The bundle loads Ponytail **before** ADHD so `normal mode` can turn both off before ADHD consumes the input. Use `stop ponytail` or `stop adhd mode` to target only one. Child agents still use the explicit extension policy below; parent style modes are not automatically loaded into ordinary children.

The old `opencode-ponytail` 4.7.3 npm artifact declares a Pi entry it does not contain. Use the maintained scoped package above, whose tarball includes the Pi extension. `i-have-adhd` is a private npm manifest, so fetch its source by fixed Git revision/hash and copy only its native Pi extension helpers, skills and license. No Claude/Gemini/OpenCode hooks are installed.

## RTK

`rtk` is available in the home profile and Pi wrapper. Its official hook delegates supported **bash** rewrites to the same pinned binary with a two-second timeout; missing/unsupported rewrites pass through. Existing read/grep tools are unchanged. Plan mode still blocks bash before RTK can execute it. Config at `~/.config/rtk/config.toml` excludes infrastructure/credential command families (`nix`, `nixos-rebuild`, `just`, `deploy`, `disko`, `tofu`, `terraform`, `ssh`, `sops`, `age`) from automatic compression. This is not an authorization policy: these commands still require their normal review.

- `rtk gain` or `rtk gain --format json`: local token statistics, **not** subscription quota.
- `rtk proxy COMMAND ...`: run without filtering; the offline test checks raw stdout and a failing exit status.
- `RTK_DISABLED=1 pi`: disable automatic rewriting for a session. An explicitly requested `rtk ...` command remains explicit.
- Do not run `rtk init`: Home Manager already supplies the hook/config. Do not install a second `pi-rtk`/token-killer wrapper.

**Privacy choice:** telemetry and full raw-output tee capture are disabled; `RTK_TELEMETRY_DISABLED=1` is also declared for the home session. The operator chose stock **local usage statistics** after testing found that RTK 0.47 ignores `tracking.enabled` and `history_days` overrides. Keep its actual enabled/90-day defaults; do not claim tracking can be disabled merely by editing that table. Its private `~/.local/share/rtk/history.db` contains command text, timing, paths and token counts; parse-failure records can include error messages. Never put passwords/tokens in command arguments. Existing home persistence covers this mutable state; nothing is committed or moved to the Nix store. RTK's output is lossy: use a raw rerun when details matter, especially before acting on a filtered diff or failure. No percentage-savings claim was measured against a real workload here.

## Languages

Pi's own wrapper PATH provides servers from **ThinkPad's locked unstable pkgs**, without installing global npm/pip packages or mixing Nixpkgs tracks:

| Language | Server | Project requirements |
|---|---|---|
| Nix | `nil` | `.nix` detection added; automatic flake archive/input evaluation disabled; this is not full flake-parts/NixOS-option evaluation |
| Python | `pyright-langserver --stdio` | Select the project's virtualenv/interpreter in `pyrightconfig.json` or its normal project configuration |
| Node.js / JS / TS / JSX / TSX | `typescript-language-server --stdio` | `tsconfig.json`/`jsconfig.json`, project dependencies; Nixpkgs supplies fallback TypeScript |
| C / C++ | `clangd` | Supply accurate `compile_commands.json` (e.g. CMake's `CMAKE_EXPORT_COMPILE_COMMANDS=ON`) or `.clangd`; no broad query-driver allowlist |

Start Pi inside the project's normal development shell for compilers, Python environments and project dependencies. These additions provide language intelligence, not a replacement build toolchain. C/C++ extensions include `.c`, `.h`, `.cpp`, `.cc`, `.cxx`, `.hpp`, `.hh`, `.hxx`; upstream classifies `.h` as C, so ambiguous headers need project compile flags. JavaScript module suffixes `.mjs`/`.cjs` and TypeScript `.mts`/`.cts` are supported upstream.

Only **trusted** projects may override servers or request eager startup in a cwd-local `.pi-lsp.json`. `/lsp-config` is a session-only override. Servers normally start on the first applicable operation and may initially return "starting"; retry after initialization. Built-in read/write/edit operations synchronize open files and running-server diagnostics. LSP findings do not replace `just check` or project tests; rename is a preview, whereas structural rewrite/code-action tools can mutate files.

## Subagents and concurrency

Defaults: parent model inheritance, fresh context, two concurrent children per run, two active background runs per session, eight cumulative spawns per run, twenty per session, maximum nesting depth one. These are **per-session/run budgets**, not a machine-wide semaphore shared by independently launched Pi instances. Scheduling is disabled; destructive cleanup/worktree discard and spawn-budget increases require confirmation. Artifacts stay under Pi session storage, not the checkout by default.

Repository/global instructions and skill discovery are retained for configured native roles. Scout/reviewer/oracle have read/search tools and supervisor communication, **no shell/edit/write**. Worker/delegate retain their mutation-capable tools for explicitly assigned implementation. Ordinary children load no ambient extensions (avoiding duplicate Rewind/provider hooks); their default does not include LSP tools. Researcher/evidence-auditor explicitly load Codex search and direct fetching and use matching tool lists/prompts rather than upstream's unavailable `web_search`/`source_check` requirements. Their Codex tools still require the existing login.

If preflight reports missing `read`, `grep`, and `ls` while the parent has them, check the loaded bundle: unpatched pi-subagents 0.67.0 misclassifies Cursor's native-display wrappers as unavailable tools. The patch below fixes detection; do not grant shell/write access, remove role restrictions or switch runners to evade that failure. A running session retains its old bundle until the updated configuration is separately activated and Pi is restarted.

Extensions and language servers run with user privileges: role restrictions and plan mode are **not an OS sandbox**. Do not treat an "execute plan" selection as authorization to deploy, enroll, format, mount or change storage. Give concurrent agents disjoint files/tasks; inspect `git status` before edits. Worktree isolation is opt-in because new worktrees do not contain another agent's uncommitted work. No automatic commit, merge, restore or worktree cleanup is configured. Alternate provider-extension children may need explicit extension selection and background mode; no provider login was tested by this change.

## Pinned adaptations and validation

`assets/pi-patches/` contains four reviewable patches applied to exact npm versions during the bundle build:

- **LSP:** add Nix/C/C++ defaults and missing suffixes; respect Pi project trust; remove duplicate code-action registration; use the protocol package's exported `/node` entry. Remove its process-wide exception suppressor and await/catch notification promises locally, including shutdown, rather than swallowing unrelated fatal errors or accumulating handlers across reloads.
- **Plan:** update the type-only Pi import and theme API; preserve/restore the previously active tools, including after reload/tree navigation; reject all non-allowlisted tools even if another extension re-enables them. No `bash` in plan mode: upstream's regex filter accepts destructive options such as `find . -delete`. Allow existing read/search/question tools only and default the next-action menu to **Stay in plan mode**. Restore saved history before enforcing explicit `--plan`, so normal/execution sessions cannot override the flag. Outside plan mode, filter only custom `pi-plan-context` messages, never user messages quoting `[PLAN MODE ACTIVE]`.

- **Subagents:** recognize builtins by their registered names even when Cursor wraps them; do not prune child extension-tool selectors against a builtin-only inventory. Keep strict child registration checks, capability ceilings and exclusions. Empty inventories remain empty and registry failures propagate instead of permitting every requested tool.
- **Ponytail:** handle `session_tree` with the same saved-mode restoration as `session_start`, so branch switches do not retain another branch's mode.

Review/retire these patches at upstream updates. The old LSP TypeBox peer is supplied explicitly as `@sinclair/typebox` 0.34.52 rather than assuming Pi's newer `typebox` satisfies it. npm lifecycle scripts are disabled; no installer script runs during activation.

`checks.x86_64-linux.pi-extensions` is part of `just check`. In a sandbox with an empty HOME and no credentials it loads the complete extension manifest through **Pi 0.85.1's actual loader**, checks tool/command/skill collisions and fetch-only registration, exercises plan transitions/guards/theme/tree state, explicit `--plan` over saved normal/execution states and quoted-marker preservation, discovers the configured subagent roles, verifies detached host-SDK aliases, exercises Cursor's real startup wrappers and all seven native roles' tool plans, checks missing-tool/registry-error/ceiling/exclusion guards and a shell-free SDK child's synthetic file read, tests style defaults/toggles/branch state/compaction and native RTK rewrite/config/statistics/raw-bypass behavior, and initializes real nil/Pyright/TypeScript/clangd servers against synthetic files. It makes no model request, activates no host, and is not live OAuth, subagent execution, interactive-TUI or real-project compilation acceptance.

Subagent repair validation, **2026-09-11**: the new regression first reproduced the missing-tool failure against the unpatched bundle, then passed with the patch. Passed LSP/whitespace checks, the targeted `pi-extensions` check, locked-shell `just fmt`, `just check`, `just ready thinkpad` (ready, no missing fields/failed assertions), and `just build thinkpad`. Final output included dirty-tree/custom-output warnings, npm environment-option/dependency deprecation notices and static-ELF patchelf notices; no failed checks remain. Pins and role permissions are unchanged. The built configuration was **not activated** and no live reviewer was retried; apply the repair through a separately authorized activation and restart Pi before the next review session.

Validation record, **2026-09-10**: passed `nix develop --no-update-lock-file -c just fmt`, `nix build --no-update-lock-file --no-link -L .#checks.x86_64-linux.pi-extensions`, the full locked-shell `just check`, and `just ready thinkpad` (ready, no missing fields/failed assertions). Final checks reported only the documented custom-output/stateVersion diagnostics and dirty-tree warning. `flake.lock` and every pre-existing npm dependency version/integrity are unchanged. Checks include the concurrent worktree's Tailscale fixtures but no live Tailscale apply; that agent's code/ciphertext remain outside this change's commit scope. Initial LSP/plan compatibility, RTK config/privacy and test-harness failures were investigated and resolved as described above/in the research ledger, not waived. Live provider login, subagent model runs, interactive UI, real-project diagnostics and host activation remain untested here.
