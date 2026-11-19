---
name: agents
description: "The agent MicroVM on bastion: a NixOS guest under microvm.nix and cloud-hypervisor where Claude Code runs unattended, its disks on apps/agents, its WAN-only network, its own tailnet node, the operator's SSH and Zed remote access, and the credentials it may hold. Use before touching modules/agents.nix or the microvm input, changing what the guest reaches or holds, or debugging the guest's boot, network or sign-in."
---

# Agents

[agents.nix](../../../modules/agents.nix) runs one guest, `agents`, as `microvm@agents` on
bastion ([microvm.nix](https://microvm-nix.github.io/microvm.nix/) host module, cloud-hypervisor).
The guest is the boundary for unattended agents: its own kernel, no fleet secret, no route to
the LANs or the tailnet's hosts. It is not a `fleet.hosts` entry: it builds inside bastion's
closure. A bastion deploy installs the guest's new system but leaves the running guest alone:
`restartIfChanged` is off, since a nixpkgs or plugin bump changes every store path in its units
and would end every session in it on each update. `agents-restart` restarts it instead, and only
when agents.nix itself, `restartGeneration` in it, the operator's login key, or one of its tokens changed since the unit
last ran; anything else, a new Claude Code included, reaches the guest at its next restart, which
bumping `restartGeneration` forces. The system a running guest booted stays a garbage-collector
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

The guest's tap carries a /24 that only bastion and the guest sit on. The `agents` nftables
table drops everything the guest sends to bastion itself, to any private, CGNAT, link-local or
multicast address, to the tailnet interface and over IPv6, and masquerades the rest to the
internet. The guest resolves through the tailnet's public resolvers. `microvm@agents` requires
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
- A tailnet peer on a home LAN cannot reach the guest directly, so its SSH and Zed sessions go
  through a relay.

## Access

`ssh agent@agents` with the operator's login key; `agent` has no sudo and the guest has no root
login, so a change to the guest is a change to agents.nix. Sessions run in tmux. Zed on the
workstations lists the guest as a remote project host; a workstation whose Zed matches the
guest's nixpkgs finds its remote server linked in `~/.zed_server`, any other downloads one there.

## Claude

`nixos.claude-agent` in [claude.nix](../../../modules/claude.nix) gives the guest the parts of
the workstations' Claude Code that need no workstation secret: the caveman, ponytail and
cache-tax plugins, the language servers, the rtk hook, and the nixos and GitHub MCP servers, the
GitHub one read-only on the token `gh` uses. They arrive as managed settings and one generated
plugin, so nothing depends on the agent's home. caveman and ponytail start at the workstations'
levels, set through their environment variables, which unlike the workstations' config files
also turns caveman on in headless runs. The guest has no jail and no Bash sandbox: the
guest itself is the boundary. Grafana's MCP server and the account's connectors stay out.

## Credentials

Whatever the guest holds, an injected prompt can use or leak. Bastion decrypts two tokens, one
from `secrets/hosts/bastion.yaml` and one from `secrets/shared/claude.yaml`, into the same
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

Commits made in the guest carry the operator's Git identity, which
[git.nix](../../../modules/git.nix) gives the guest and the workstations alike, and no Claude
attribution, which the managed settings blank as the workstations' settings do.

The share holds nothing else of bastion's. No sops identity, deploy key, build key or cache write
access goes in.
