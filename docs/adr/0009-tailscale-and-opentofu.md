# ADR 0009 — Staged Tailscale clients and OpenTofu tailnet ownership

- Status: accepted design; ThinkPad unactivated candidate enabled, other rollouts disabled
- Date: 2026-09-10

## Context

The operator wants declarative enrollment for all three machines plus a personal/family tailnet with default-deny, device-specific access. Native Tailscale GitOps owns only the policy file; OpenTofu also manages supported tailnet settings. A prior policy-only apply and no-drift verification were operator-reported complete, but per-host enrollment is unexecuted and Racknerd/Bastion remain blocked on identity, closure-trust and OS commissioning gates (evidence in [hosts.md](../hosts.md#current-status)). Deploying before those gates resolve could lose root-only access or mishandle boot/storage migration.

## Decision

- The daemon and private persistence live in a cohesive class-checked deferred `tailscale` capability using each host's own Nixpkgs. Every host composes it; `fleet.tailscale.enable` is true **only for ThinkPad's unactivated candidate**, after operator-reviewed state/backup and exact-tag key provisioning. This deliberate staged-rollout exception to enable-on-import keeps missing feature prerequisites visible in `tailscalePlan` while preserving commissioned ThinkPad's behavior. Enabling requires genuine state/policy review and a selected enrollment mode through normal bootstrap assertions; review flags record actual review, never a shortcut, and no OS commissioning flag changes.
- Persist only `/var/lib/tailscale`, root-only backing with explicit mount dependencies. Authentication uses per-host SOPS-delivered keys via the CLI's file-reference API, not secret values in argv/store inputs. Preserve running identities; reconnect stopped identities without resubmitting keys; fail for pending approval or unreviewed/missing enrollment; reconcile explicit non-routing/non-SSH preferences. No blanket trusted interface or forced state reset; existing private state is never read or migrated by evaluation/activation code.
- Plain OpenTofu HCL with a separate policy file under `tofu/tailscale/` — no Terranix layer, new flake inputs, host package mixing or second policy publisher. Stable development tooling supplies OpenTofu and a Nix-pinned offline provider mirror. `tofu/tailscale/tailnet.json` is the single shared public tailnet identity; environment confirmation cannot retarget the provider or state wrapper. Initially manage only the whole policy and MagicDNS; existing resources must be imported/reviewed; destruction/reset protections and native publisher/editor conflicts stay explicit.
- Access policy: only ThinkPad may initiate TCP 22 and ICMP toward Racknerd and Bastion; no other peer access, including family/self-device access. Individual administrator-controlled fleet tags must each identify exactly one intended device; ordinary OpenSSH/account/privilege rules are unchanged.
- Encrypted local state, saved plans and provider data stay outside Git/Nix store, bound to one tailnet and the explicitly selected default workspace, with PBKDF2/AES-GCM and no plaintext fallback, using a runtime ephemeral passphrase. Provider configuration is isolated; provider reattachment is rejected. Preserve upstream's encrypted `errored.tfstate` fallback and the [emergency recovery procedure](../tailscale.md#emergency-state-recovery). Recovery, credential provisioning, policy adoption and applies remain explicit operator operations; neither shell entry, checks nor rebuilds apply the tailnet configuration. Operator-only `tailnet verify` performs a non-saving, read-only API plan with detailed no-change/drift/error results.

## Consequences

- The repository validates staged and synthetic enabled configurations without pretending hosts are enrolled. Checks cannot verify actual credentials, policy-engine acceptance, tag cardinality, network isolation, boot or recovery ([validation scope](../validation.md)).
- Tailnet policy replacement affects every existing member/device; MagicDNS is tailnet-wide and must be reviewed before apply. Tagged identities have different ownership/expiry behavior from user-owned devices. Per-device key creation/delivery and protected state/key backups are bootstrap responsibilities, not reasons to put reusable administration credentials on fleet hosts.
- Only separately authorized commissioning/activation enrolls a real host, preserving access/rollback/recovery and Bastion NAS boundaries.

See [procedure, current inventory and limitations](../tailscale.md) and [research](../research.md).
