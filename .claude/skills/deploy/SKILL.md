---
name: deploy
description: "deploy-rs: how a host's committed configuration is activated over the tailnet with magic rollback, the deploy account and what it may run, the deploy checks, when to deploy versus install. Use before touching modules/deploy.nix, the deploy account or sudo rules, and before preparing any deploy command."
---

# Deploy

[deploy.nix](../../../modules/deploy.nix) turns every `fleet.hosts` entry into a deploy-rs node
reached by its MagicDNS name as the `deploy` account, which may only run the activation script
and remove the rollback canary through sudo. Magic rollback and auto rollback stay on: a profile
that breaks the SSH path reverts after the confirm timeout. `nix flake check` carries the
deploy-rs schema and activation checks per system.

```sh
nix run .#deploy -- .#HOST          # after checks pass on the committed revision
nix run .#deploy -- .#HOST --boot   # set the boot default only, no activation
```

Claude prepares the command and asks first ([CLAUDE.md](../../../CLAUDE.md#autonomy)); a deploy
that changes SSH, firewall, Tailscale, users, sudo or this module is an access change. The first
activation of a host is a nixos-anywhere install, not a deploy. A host without a tailnet
connection is unreachable to deploy-rs by design: recover through the provider or physical
console.
