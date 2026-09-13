# Pi extensions

ThinkPad's public configuration lives in `modules/agents.nix`, with checks under `modules/agents/`, and contributes through native Home Manager to the desktop bundle. Neither minimal-server candidate selects agents, editors or Home Manager. Follow [manual validation](../../validate/SKILL.md), including the ciphertext guard before staging/evaluation; no repository tasks or automatic test gate exist.

## Package management

Extensions are declared directly in managed `settings.packages` as pinned `npm:` specs. There are no local store extensions, vendored npm manifest/lock, patches or Nix npm builds. Versioned specs are skipped by `pi update --extensions`; Pi installs missing packages into mutable `~/.pi/agent/npm` using npm on startup, requiring network access. `nodejs` stays in Pi's wrapper PATH for this. Package versions are pinned, not their entire mutable npm dependency trees.

The Home Manager settings file is read-only. Change the declaration rather than using `pi install`, `/curator` or settings-writing commands. A separately authorized activation and a **new Pi session** are required; changing this repository does not alter the running session. Credentials, installed package trees, sessions, trust decisions and artifacts stay private mutable home state. Declarative removal does not erase old npm trees, RTK history, credentials or generations, and does not disable a separately installed project-local extension.

## Enabled packages

| Package | Pin | Configuration / use |
|---|---|---|
| `@99percentpeople/pi-codex-api` | 0.4.0 | Codex search/quota/image tools; `~/.pi/agent/99extensions.json` retains `gpt-image-2`, quota status and `allowOtherProviders` |
| `@akepka/pi-cursor-cli-provider` | 0.10.1 | Cursor provider; its CLI resolves through `CURSOR_AGENT_PATH` |
| `@dietrichgebert/ponytail` | 4.9.0 | Native Pi extension and six skills; stock upstream package, no restored patches/config |
| `@juicesharp/rpiv-ask-user-question` | 2.9.0 | `~/.config/rpiv-ask-user-question/config.json`: collapse key `ctrl+]` |

Pi retains `openai-codex/gpt-6-astra`, thinking level **high**, and project trust **ask**. Use `codex_search` for search/navigation; the old `pi-web-access` direct-fetch tools remain absent.

## Ponytail

The published manifest loads `pi-extension/index.js` and `skills/`, not installers/hooks for other agents. With no environment or private config override, upstream defaults are **full** mode, visible status and a startup notification. This re-addition does not restore the former managed `~/.config/ponytail/config.json` or patches. Existing private config/session entries can affect the effective mode; review them after authorized activation.

- `/ponytail lite|full|ultra|off` changes the session mode; `/ponytail status` reports it. Bare `/ponytail` sets the configured default (or full when the default is off), despite the upstream README's report-only claim.
- Prefer explicit `/skill:ponytail-review`, `/skill:ponytail-audit`, `/skill:ponytail-debt`, `/skill:ponytail-gain` and `/skill:ponytail-help`. Stock 4.9.0's shorthand aliases send messages without Pi 0.85.1's explicit expansion opt-in, so they are not reliable native skill expansion.
- Stock 4.9.0 restores mode on `session_start`, not `session_tree`; after tree navigation explicitly select the intended mode. The former tree/alias patches are not carried into mutable npm installs.
- Ponytail is style guidance, not deployment authorization or a substitute for correctness/security review. Repository safety, validation and the no-prose-code-comments policy still apply; put rationale in skills, not `ponytail:` comments. Its gain card describes upstream benchmarks, not savings measured here.

See [package/source research](../../nix-research/references/research.md#pi-extension-removals-and-ponytail-restoration--2026-09-13).

## Removed packages

On 2026-09-13 the operator removed RTK, `pi-tool-repair`, `@ayulab/pi-rewind`, the local `empty-args-retry.ts` and `pi-review`. Their hook/source pins, RTK home/wrapper package and telemetry/config wiring, tool-repair config and `ayu` rewind/checkpoint settings are removed too. There is no replacement argument repair/retry, command compression, checkpoint restoration or `/review` extension. Pi's own provider retry behavior remains unchanged; Ponytail review is a distinct over-engineering skill.

Earlier removals remain: `pi-subagents`, `pi-web-access`, `pi-plan`, `pi-lsp-extension`, `i-have-adhd`, `@juicesharp/rpiv-todo`, `pi-claude-bridge` and both Herdr Pi extensions. No subagents, plan mode, LSP tools, direct-fetch tools, AskClaude or Herdr pane reporting are restored. The Herdr program remains unchanged; only `cursor-cli` is allowed by the desktop unfree predicate. Git history and the research ledger retain prior pins/configuration.

## Installed-server boundary

Bastion's temporary [administration workspace](../../storage-disko/references/reinstall.md#bastions-temporary-administration-workspace) was removed from the candidate because the operator uses the MacBook. Its accepted installed generation still has Pi 0.75.4/RTK 0.41.0 and the home bind until the separately authorized boot-only transition. Pi 0.75.4 cannot enforce project trust **ask**: use only operator-reviewed checkouts until then. No package removal here changes that installed generation or erases its private home.

## Validation

`checks.x86_64-linux.pi-extensions` checks generated settings/configuration and runs the packaged Pi version command with empty HOME and no credentials. It asserts exactly the four reviewed npm pins with no local entries, unchanged model/trust/Codex preferences, absent rewind settings, and no managed tool-repair config, RTK config/environment or RTK home/wrapper packages. Obsolete local-loader, retry-transform and RTK runtime tests were deleted with their implementations; the check name/count stays unchanged.

The offline sandbox does **not** install or load these mutable npm packages or establish provider/session compatibility. Real acceptance requires a new Pi session after authorized activation, including Ponytail mode/status and explicit skill invocations. ThinkPad's fresh-layout candidate remains unready; no assertion bypass or live activation is a test. Server closures are unaffected, and `serverBaseline` continues checking absent desktop/workspace tools and ephemeral homes.
