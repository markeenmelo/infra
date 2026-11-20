---
name: hermes
description: "The Hermes MicroVM on bastion: Nous Research's Hermes Agent as a long-lived assistant reached through a Telegram bot, its model from the operator's ChatGPT subscription, the guest that confines it, the two secrets it holds and how its sign-in is renewed. Use before touching modules/hermes.nix or the hermes-agent input, changing the model, who may talk to the bot or what the guest reaches, or debugging the bot not answering."
---

# Hermes

[hermes.nix](../../../modules/hermes.nix) runs a third guest on bastion, `hermes`, from
[_guest.nix](../../../modules/_guest.nix) like the downloads guest ([arr skill](../arr/SKILL.md)):
cloud-hypervisor, its own /24 on a tap ([_hermes.nix](../../../modules/_hermes.nix)), internet
only, nothing of bastion, the LANs or the tailnet reachable but the home gateway's public address
([agents skill](../agents/SKILL.md) names that limit), no login, journal on the console
and so in `microvm@hermes`'s log. Inside runs
[Hermes Agent](https://github.com/NousResearch/hermes-agent) through upstream's own NixOS
module, from the `hermes-agent` flake input, pinned to a release tag in `flake.nix`: a bump is a
new tag there, then `nix flake update hermes-agent`. The input keeps the nixpkgs upstream locked,
the one exception to every host following one nixpkgs: upstream patches `patchelf` for that
revision and the patch does not apply to the fleet's. The package is upstream's `messaging`
variant, the chat gateways without the terminal UI, web and desktop parts. Evaluating it reads
its Python workspace from a filtered copy of the source, which a read-only evaluation
(`nix flake check --no-build`, `nix eval --read-only`) cannot add to the store: evaluate the
package once without it first, as [check.yml](../../../.github/workflows/check.yml) and `just check`
do.

The agent runs shell commands and writes files as its own account inside the guest, and upstream
is plain that only isolation by the operating system holds against a model that turns hostile:
its approval prompts are heuristics. The guest is that isolation. Whatever it holds, a message
or a web page can talk the agent into using or leaking.

- **Reached by:** a Telegram bot, by long polling, so nothing listens. Only the user ids in
  `TELEGRAM_ALLOWED_USERS` are answered; anyone else is ignored without a reply.
- **Model:** `gpt-6-luna` through the `openai-codex` provider, which is the operator's ChatGPT
  subscription, not an API key.
- **Browser:** the fleet's Chromium, named in `browser.executable_path` because upstream's own
  download cannot run on NixOS, with one persistent profile under the agent's home
  (`browser.user_data_dir`), so a site the operator had it sign in to stays signed in. That
  session is one more thing the guest holds: any page the agent reads can steer what it does
  with those accounts.
- **State:** `var.img` on `apps/agents` holds `/var/lib`, with the agent's memory, skills,
  sessions and its refreshed sign-in under `/var/lib/hermes`. Neither snapshotted nor backed up.

## Secrets

Two, in `secrets/hosts/bastion.yaml`, copied into `/run/hermes-secrets` when the guest's virtiofs
daemons start and mounted read-only in the guest before activation, which is when upstream's
module reads them. A change restarts the guest.

- `hermes/env`: lines of `NAME=value`, at least `TELEGRAM_BOT_TOKEN` (from BotFather) and
  `TELEGRAM_ALLOWED_USERS` (comma-separated numeric ids).
- `hermes/auth`: the `auth.json` that `hermes auth add openai-codex` writes. The operator runs
  that once on a workstation, in a throwaway `HERMES_HOME`, follows the device code, and stores
  the file. `hermes-auth` in the guest installs it whenever its content differs from the one it
  installed last, a record it keeps where the agent cannot write, and writes it as the agent's
  account; in between, Hermes refreshes the sign-in itself and keeps it on its disk. The
  refresh token is single-use: the stored copy goes stale after the first refresh, which is
  fine until the sign-in dies and a new one is stored. Never share that login with Codex CLI.
