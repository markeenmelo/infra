# ADR 0004 — Opt-in, readiness-gated deploy-rs

- Status: accepted; dedicated account/groups amendment 2026-09-13 supersedes the signed/interactive policy in [ADR 0005](0005-existing-headless-baseline.md)
- Date: 2026-09-09

## Context

Remote activation requires real identity, elevation, closure trust, resources and recovery, not merely schema-valid nodes. The operator now selected `deploy` on every host, using the two existing administrator keys; remove interactive server accounts, retain ThinkPad's `marcos`, use remote builds, and deploy Racknerd before Bastion.

## Decision

- `modules/deploy.nix` owns deployment metadata, account capability, all real deployment facts, target-scoped activation libraries, nodes/groups/order, and both-track/real-host checks. Public administrator keys remain with their access owner. No second production Nix entry point or global overlay.
- Expose nodes only for `ready && deployment.enable`. Explicit nullable endpoints/groups stay commissioning blockers; ThinkPad stays unready and disabled. `deploymentGroups` includes unready members for planning, not as executable targets.
- Dedicated system account `deploy` has a locked password, restricted public keys, ephemeral private home and wheel membership. Membership reflects its real administrator role and satisfies native keyed-administrator recovery checks; wheel sudo still requires a password. Only activate-rs and its canary removal receive NOPASSWD. Nix trust is exactly root plus deploy, with signature enforcement retained. Arbitrary NixOS builds/activation make this **root-equivalent** regardless of command restrictions.
- Upstream `activate.nixos`, `deployChecks` and executable share one locked source. Activation uses each target's track. Root activates through `sudo -n -u`; SSH login remains non-root, public-key-only, batch/strict, without agent forwarding or key-enabled PTYs. Automatic/magic rollback and bounded SSH liveness remain enabled.
- Remote builds use the target's ssh-ng store and durable `/nix/var/nix/builds`. No Nix trust for marcos or all wheel members. Old public signing keys remain for staged recovery; private signing keys are neither loaded nor installed by the new workflow.
- Groups are servers/workstations, with explicit order metadata and independent real-host order assertions. Native group filtering does not guarantee order; the operator runner must expand explicit targets Racknerd then Bastion. Native remote builds can overlap; activation follows target order and a later failure can roll back earlier successful targets.

## Consequences

A first transition must provision/verify the new account through console or staged old access before removing the only working login. Bastion's pending home-bind removal requires boot-only selection and a separate reboot. No activation script deletes old homes, credentials or machine identities. Removing users/password delivery does not erase historical backing data, ciphertext or prior generations and is not cryptographic revocation.

Local both-track fixtures and builds never contact hosts or establish boot/access acceptance. Rollback does not restore data, disks or secrets or guarantee a future boot. See [operations](../../../deploy/references/operations.md) and [research](../../../nix-research/references/research.md).
