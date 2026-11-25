---
name: guests
description: "The MicroVMs on bastion: the agents guest where Claude Code and the other coding agents run unattended (its disks, WAN-only network, tailnet node, Paseo, the GitHub App token and other credentials it holds) and the Hermes guest running Nous Research's Hermes Agent behind a Telegram bot on the operator's ChatGPT subscription. Use before touching modules/{agents,claude,hermes,_guest}.nix or the microvm, paseo and hermes-agent inputs, changing what a guest reaches or holds, or debugging a guest's boot, network, sign-in or bot."
---

# Guests

Read the file for the guest you touch; each holds what its module cannot say.

| File | Guest | Modules |
|---|---|---|
| [agents.md](agents.md) | Coding agents, Paseo, the GitHub App token | `agents.nix`, `claude.nix` |
| [hermes.md](hermes.md) | Hermes Agent behind Telegram | `hermes.nix`, `_hermes.nix` |

Both of bastion's guests are built from [_guest.nix](../../../modules/_guest.nix): the
cloud-hypervisor guest, its tap and /24, and the nftables table that confines it. What each guest
reaches and holds is in its file.
