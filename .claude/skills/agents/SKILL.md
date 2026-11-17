---
name: agents
description: "The agent MicroVM on bastion: a NixOS guest under microvm.nix and cloud-hypervisor where Claude Code runs unattended, its disks on apps/agents, its WAN-only network, its own tailnet node, the operator's SSH and Zed remote access, and the credentials it may hold. Use before touching modules/agents.nix or the microvm input, changing what the guest reaches or holds, or debugging the guest's boot, network or sign-in."
---

# Agents

[agents.nix](../../../modules/agents.nix) runs one guest, `agents`, as `microvm@agents` on
bastion ([microvm.nix](https://microvm-nix.github.io/microvm.nix/) host module, cloud-hypervisor).
The guest is the boundary for unattended agents: its own kernel, no fleet secret, no route to
the LANs or the tailnet's hosts. It is not a `fleet.hosts` entry: it builds inside bastion's
closure and a bastion deploy that changes it restarts it, ending every session in it.
`microvm@agents` requires `install-microvm-agents`, which points the guest at its new system:
upstream only orders the two, so a switch could restart the guest before the link moved and boot
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
internet. The guest resolves through the tailnet's public resolvers.

The guest joins the tailnet as `tag:agent`
([main.tf](../../../opentofu/tailscale/main.tf)): admin clients reach its port 22 and the tag is
the source of no grant. Its key is `agents/tailscale-auth-key` in `secrets/hosts/bastion.yaml`,
moved from the `enrollment_keys` output like a host's ([tailnet skill](../tailnet/SKILL.md)) and
read once, when `state.img` holds no login.

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
plugin, so nothing depends on the agent's home. The guest has no jail and no Bash sandbox: the
guest itself is the boundary. Grafana's MCP server and the account's connectors stay out.

## Credentials

Whatever the guest holds, an injected prompt can use or leak. Bastion decrypts two tokens from
`secrets/hosts/bastion.yaml` into the same read-only share as the tailnet key, owned by `agent`,
and every shell in the guest exports them; a changed token restarts the guest:

- `agents/claude-token`: the token from `claude setup-token`, exported as
  `CLAUDE_CODE_OAUTH_TOKEN`. It makes model requests only. `/login` instead would hand the guest
  Remote Control and the account's connectors.
- `agents/github-token`: a fine-grained token, exported as `GH_TOKEN` and handed to Git by `gh`,
  limited to Contents and Pull requests writes and Actions read on the repositories the agents
  work on, with the default branch protected. Never the Workflows permission, which would let a
  push change what CI runs with its secrets.

The share holds nothing else of bastion's. No sops identity, deploy key, build key or cache write
access goes in.
