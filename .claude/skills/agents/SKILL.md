---
name: agents
description: "The agent MicroVM on bastion: a NixOS guest under microvm.nix and cloud-hypervisor where Claude Code runs unattended, its disks on apps/agents, its WAN-only network, its own tailnet node, the operator's SSH and Paseo access, and the credentials it may hold. Use before touching modules/agents.nix or the microvm input, changing what the guest reaches or holds, or debugging the guest's boot, network or sign-in."
---

# Agents

[agents.nix](../../../modules/agents.nix) runs one guest, `agents`, as `microvm@agents` on
bastion ([microvm.nix](https://microvm-nix.github.io/microvm.nix/) host module, cloud-hypervisor).
The guest is the boundary for unattended agents: its own kernel, no fleet secret, no route to
the LANs or the tailnet's hosts. It is not a `fleet.hosts` entry: it builds inside bastion's
closure. A bastion deploy installs the guest's new system but leaves the running guest alone:
`restartIfChanged` is off, since a nixpkgs or plugin bump changes every store path in its units
and would end every session in it on each update. `agents-restart` restarts it instead, and only
when agents.nix, the shared [_guest.nix](../../../modules/_guest.nix), the operator's login key, or one of its tokens changed since the unit
last ran; anything else, a new Claude Code included, reaches the guest at its next restart. The system a running guest booted stays a garbage-collector
root until then.
`microvm@agents` requires `install-microvm-agents`, which points the guest at its new system:
upstream only orders the two, so a restart could boot the guest before the link moved, into
the previous system. The guest's kernel command line in `microvm@agents`'s log names the system
it booted.

cloud-hypervisor, not QEMU: the QEMU runner opens its disks with io_uring, which
[server.nix](../../../modules/server.nix) disables. It cannot pass systemd credentials, so the
secrets the guest gets come over a read-only virtiofs share. `microvm.vsock.cid` stays unset,
at the cost of an evaluation warning, so the guest has no channel to the host's systemd.

## Disks

The guest's Nix store is a read-only image built with bastion, under a writable overlay, so
`nix build` works inside. `/var/lib/microvms` is the dataset `apps/agents`
([data.nix](../../../modules/hosts/bastion/data.nix)), neither snapshotted nor backed up: work
that matters is pushed. Three images live there: `store.img` (the overlay, deleted before every
start because the guest's Nix database starts empty), `state.img` (`/var/lib`: the tailnet node,
the SSH host key) and `home.img` (`/home`). The root is memory and is lost on restart.

## Network

The guest's network and host wiring come from [_guest.nix](../../../modules/_guest.nix), as for
the downloads and hermes guests ([arr skill](../arr/SKILL.md)). Its tap carries a /24 that only
bastion and the guest sit on. The `agents` nftables table drops everything the guest sends to
bastion itself, to any private, CGNAT, link-local or multicast address, to the tailnet interface
and over IPv6, and new connections forwarded towards it, and masquerades the rest to the
internet. The guest resolves through the tailnet's public resolvers. Unlike the other guests it
keeps its journal off the console (`services.journald.settings.Journal.ForwardToConsole` is
forced off), so nothing a process in it logs lands in bastion's journal. `microvm@agents` requires
`nftables.service`, so the guest does not run without the ruleset: a firewall that fails to load
keeps it down, and one that is stopped or restarted takes it along. A switch reloads the ruleset
and leaves the guest alone.

The guest joins the tailnet as `tag:agent`
([main.tf](../../../opentofu/tailscale/main.tf)): admin clients reach its port 22 and the tag is
the source of no grant. Its key is `agents/tailscale-auth-key` in `secrets/hosts/bastion.yaml`,
moved from the `enrollment_keys` output like a host's ([tailnet skill](../tailnet/SKILL.md)) and
read once, when `state.img` holds no login, so a refreshed key does not restart the guest.

Two limits of filtering by destination address:

- The home gateway's own WAN address is public, so the guest reaches the gateway there,
  masqueraded as bastion: its DNS, NTP and the sign-in page of its HTTPS interface, which the
  LAN firewall ([opentofu skill](../opentofu/SKILL.md)) admits from bastion for the tailnet's
  admin clients. Accepted: the guest holds no gateway credential.
- A tailnet peer on a home LAN cannot reach the guest directly, so its SSH and Paseo sessions go
  through a relay.

## Access

`ssh agent@agents` with the operator's login key; `agent` has no sudo and the guest has no root
login, so a change to the guest is a change to agents.nix. Agent sessions run under Paseo (below).

## Claude

`nixos.claude-agent` in [claude.nix](../../../modules/claude.nix) gives the guest the parts of
the workstations' Claude Code that need no workstation secret: the caveman, ponytail and
cache-tax plugins, the language servers, the rtk hook, and the nixos and GitHub MCP servers, the
GitHub one read-only on the token `gh` uses. They arrive as managed settings and one generated
plugin, so nothing depends on the agent's home. caveman and ponytail start at the workstations'
levels, set through their environment variables, which unlike the workstations' config files
also turns caveman on in headless runs. The guest has no jail and no Bash sandbox: the
guest itself is the boundary. Grafana's MCP server and the account's connectors stay out.

## Paseo and the other agents

Codex, Cursor's CLI (`cursor-agent`), OpenCode and pi sit beside Claude Code. Codex, OpenCode
and pi are configured through their Home Manager modules for `agent`, in `agent-tools` in
[claude.nix](../../../modules/claude.nix): telemetry, sharing and self-update off, and the same
nixos and read-only GitHub MCP servers Claude gets, the GitHub one reading the token file. The
[Paseo](https://paseo.sh) daemon runs any of them for its desktop, web and mobile clients,
through the module of Paseo's own flake (the `paseo` input) on nixpkgs' package. The daemon runs
as `agent` with the same tokens a shell gets, written for it at each start to a file only
`agent` reads, with its relay off (`--no-relay`). It listens on `fleet.paseoPort`, which the
guest's firewall opens on the tailnet interface only and the tailnet policy grants to admin
clients alone ([opentofu skill](../opentofu/SKILL.md)), and asks every client for the daemon
password, `agents/paseo-password` in `secrets/hosts/bastion.yaml`, exported as `PASEO_PASSWORD`
like the tokens below; it may not hold a single quote, and the token script fails the unit, so the daemon does not
start, without it. The phone app connects to `agents` on that port; the desktop app (`paseo-desktop` in
[desktop.nix](../../../modules/desktop.nix)) as a Remote SSH host `ssh://agent@agents`; a browser through `ssh -N -L 6767:127.0.0.1:6767
agent@agents` and `http://localhost:6767`. The daemon accepts only `agents`, `localhost` and
IP addresses as host names and refuses a browser origin other than `localhost`, so a web page
cannot drive it. Traffic to it is plain HTTP inside the tailnet's WireGuard. Paseo's state, `~/.paseo`, lives on `home.img`.

## Credentials

Whatever the guest holds, an injected prompt can use or leak. Bastion decrypts two tokens and the Paseo password, the password and one token
from `secrets/hosts/bastion.yaml` and one token from `secrets/shared/claude.yaml`, into the same
read-only share as the tailnet key, owned by `agent`'s
uid, which no account on bastion holds,
and every shell in the guest exports them; a changed token restarts the guest, through `agents-restart`:

- `claude-token` in `secrets/shared/claude.yaml`: the token from `claude setup-token`, exported
  as `CLAUDE_CODE_OAUTH_TOKEN`. It makes model requests only. `/login` instead would hand the
  guest Remote Control and the account's connectors. The workstations read the same secret
  ([secrets skill](../secrets/SKILL.md)).
- `agents/github-token`: a fine-grained token, exported as `GH_TOKEN` and handed to Git by `gh`,
  limited to Contents and Pull requests writes and Actions read on the repositories the agents
  work on, with the default branch protected. Never the Workflows permission, which would let a
  push rewrite the workflows themselves. Contents write alone still lets a pushed branch change
  the code a pull-request workflow runs, so the token covers only repositories whose
  pull-request workflows hold no secret that such code can reach. It also merges: an agent
  squash-merges its own pull request once the reviewers find nothing
  ([CLAUDE.md](../../../CLAUDE.md#branches-and-pull-requests)), so for those the two reviewers,
  which only read the diff, are the gate before `main`. The changes CLAUDE.md keeps for the
  operator to merge are a rule the agent follows, not a control: an injected session holding this
  token can merge whatever the branch protection admits.

Codex, Cursor, OpenCode and pi hold no secret of the repository: the operator signs each in once
over SSH (`codex login --device-auth`, `cursor-agent login`, `opencode auth login`, `/login` in
`pi` for each of its providers, such as Kimi, Z.ai and MiniMax), and the
session lands in `agent`'s home on `home.img`, where it survives restarts and is not backed up.
Each is a whole-account session for that service, usable and leakable like the tokens above;
revoke it from the service's own account page.

Commits made in the guest carry the operator's Git identity, which
[git.nix](../../../modules/git.nix) gives the guest and the workstations alike, and no Claude
attribution, which the managed settings blank as the workstations' settings do.

The share holds nothing else of bastion's. No sops identity, deploy key, build key or cache write
access goes in.
