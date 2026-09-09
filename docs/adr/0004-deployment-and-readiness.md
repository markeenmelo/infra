# ADR 0004 — Opt-in, readiness-gated deploy-rs

- Status: accepted
- Date: 2026-09-09

## Context

Addresses/accounts are unknown; laptops and gaming machines may be offline. Remote NixOS activation needs SSH, elevation, closure trust and a recovery path, not merely a schema-valid node.

## Decision

Expose nodes only when `fleet.hosts.<name>.ready && deployment.enable`. Servers intend deployment; desktops opt in. Keep nullable address/account placeholders and typed metadata separate from host identity, hardware and package selection. Add deployment SSH/state requirements through the host's deferred module.

Use upstream `activate.nixos` and `deployChecks`. Scope its overlay to each target's package set so activation code and executable use the target track. Build the executable from the same locked upstream source as the library. Preserve automatic and magic rollback, interactive sudo defaults and bounded SSH liveness.

Require explicit closure transport trust: root-equivalent per-user Nix trust, or separately provisioned signing keys. Never broadly trust wheel or embed secrets. NixOS system activation runs as root; the SSH account and elevation mechanism remain separate. The deployment SSH account must be non-root, matching the SSH capability's `PermitRootLogin = "no"` policy. Enabled deployments assert this even if root has authorized keys; null remains a commissioning blocker. Do not enable SSH root login to accommodate invalid deployment metadata.

## Consequences

The uncommissioned deployment set is empty rather than fake-address nodes. Upstream production checks are supplemented with non-empty both-track smoke checks and evaluated NixOS activation fixtures. Once real hosts are enabled, upstream activation checks may build full closures, including outside a selected deploy subset. CI only builds/evaluates, never deploys.

Rollback does not undo data migrations, disk provisioning or a future boot failure. SSH-breaking changes need staged access or console-controlled maintenance. An offline desktop is excluded by policy, not hidden by ignoring deployment errors.

See [operations](../operations.md), [research](../research.md), `modules/deployment.nix`.
