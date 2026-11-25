---
name: operating
description: "Running the fleet: deploy-rs with magic rollback over the tailnet, the deploy account and its sudo rules, the deploy checks and the nixos-anywhere install that carries a host's SSH and tailnet identity; SOPS and sops-nix, which file and recipients hold a key, how a unit receives a secret, rotating a key, the secrets check; Tailscale on every host, joining and rejoining, the auth key and its tag, the PIA exit nodes. Use before touching modules/{deploy,install,secrets,tailscale,vpn-exit}.nix, secrets/, .sops.yaml, sops.secrets, any credential or tailscale0 firewall rules, before preparing a deploy or install command, and when asked where a credential lives or how a host joins the tailnet."
---

# Operating

Read the file for the task:

| File | Covers | Modules |
|---|---|---|
| [deploy.md](deploy.md) | Deploys, the deploy account, the remote apps, installs | `deploy.nix`, `install.nix` |
| [secrets.md](secrets.md) | SOPS files and recipients, delivery to units, editing, a new host | `secrets.nix`, `.sops.yaml`, `secrets/` |
| [tailnet.md](tailnet.md) | Joining the tailnet, the auth key, reinstalls, PIA exit nodes | `tailscale.nix`, `vpn-exit.nix` |

The agent only prepares deploys, installs and secret edits; [CLAUDE.md](../../../CLAUDE.md#autonomy)
says who runs them. The tailnet's policy and tags are OpenTofu
([opentofu skill](../opentofu/SKILL.md)).
