# ADR 0004 — Opt-in, readiness-gated deploy-rs

- Status: accepted; current-host deployment policy in [ADR 0005](0005-existing-headless-baseline.md)
- Date: 2026-09-09

## Context

Addresses and accounts may be unknown, and machines may be offline. Remote activation needs SSH, elevation, closure trust and a recovery path — not merely a schema-valid node.

## Decision

- Expose deploy nodes only when `fleet.hosts.<name>.ready && deployment.enable`. Servers intend deployment; desktops opt in. Nullable address/account placeholders and typed deployment metadata stay separate from identity, hardware and package selection; SSH/state requirements attach through the host's deferred module.
- Use upstream `activate.nixos` and `deployChecks`, building the executable from the same locked upstream source as the library. Scope the overlay to each target's package set so activation code uses the target track. Preserve automatic and magic rollback, interactive sudo defaults and bounded SSH liveness.
- Closure transport trust is explicit: root-equivalent per-user Nix trust (`trusted-user`), or separately provisioned signing keys. Never broadly trust wheel or embed secrets. NixOS activation runs as root; the SSH account is non-root and the elevation mechanism is separate. Enabled deployments assert a non-root SSH user matching the `PermitRootLogin = "no"` policy even if root has keys; null stays a commissioning blocker. Never enable SSH root login to accommodate invalid deployment metadata.

## Consequences

- The uncommissioned deployment set is empty rather than fake-address nodes. Upstream production checks are supplemented with non-empty both-track smoke checks; once real hosts are enabled, upstream activation checks may build full closures, including outside a selected deploy subset. CI only builds/evaluates, never deploys.
- Rollback does not undo data migrations, disk provisioning or a future boot failure. SSH-breaking changes need staged access or console-controlled maintenance. An offline desktop is excluded by policy, not hidden by ignoring deployment errors.

See [operations](../operations.md), [research](../research.md), `modules/deployment.nix`.
