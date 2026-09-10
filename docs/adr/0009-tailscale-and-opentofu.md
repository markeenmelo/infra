# ADR 0009 — Staged Tailscale clients and OpenTofu tailnet ownership

- Status: accepted design; rollout disabled pending verified bootstrap facts
- Date: 2026-09-10
- Amends the VPN deferral in ADR 0005 and the Tailscale exclusion in ADR 0006

## Context

The operator wants declarative enrollment for all four fleet machines, plus a personal/family tailnet with default-deny device-specific access. Native Tailscale GitOps owns only the policy file; OpenTofu also manages supported tailnet settings. An existing tailnet is intended, but its ID/credentials have not been supplied. Old remote configurations have active, unauthenticated daemons and retained private state. Three hosts still fail OS commissioning; deploying before inspection could lose root-only access or mishandle boot/storage migration.

## Decision

- Keep the daemon and private persistence in a cohesive class-checked deferred `tailscale` capability, using each host's own Nixpkgs. Every host composes it, but its explicit `fleet.tailscale.enable` is **false**. This intentional staged-rollout exception to enable-on-import preserves commissioned ThinkPad's existing behavior while missing feature prerequisites remain visible separately in `tailscalePlan`. Enabling enforces genuine state/policy review and a selected enrollment mode through normal bootstrap assertions; no host-ready/review flag is changed to pass evaluation.
- Persist only `/var/lib/tailscale`, with root-only backing and explicit mount dependencies. Authentication uses per-host SOPS-delivered keys via the CLI's file-reference API, not secret values in argv/store inputs. Preserve running identities, reconnect stopped identities without resubmitting keys, fail for pending approval or unreviewed/missing enrollment, and reconcile explicit non-routing/non-SSH preferences. No blanket trusted interface or forced state reset. Existing private state is neither read nor migrated by evaluation/activation code.
- Use plain OpenTofu HCL and a separate policy file under `tofu/tailscale/`; no Terranix layer, new flake inputs, host package mixing or second policy publisher. Stable development tooling provides OpenTofu and a Nix-pinned offline provider mirror. Only the whole policy and MagicDNS are initially managed. Existing resources must be imported/reviewed, destruction/reset protections remain, and native publisher/editor conflicts require explicit reconciliation.
- Allow only ThinkPad to initiate TCP 22 and ICMP toward Racknerd, Bastion and Dino. No other peer access, including family/self-device access. Use individual administrator-controlled fleet tags; administrators must ensure each tag identifies exactly one intended device. Tags are not unique hardware identities; keys/tag administration are security-sensitive. Ordinary OpenSSH/account/privilege rules remain unchanged.
- Keep encrypted local state, saved plans and provider data outside Git/Nix store, bound to one tailnet. Enforce PBKDF2/AES-GCM with no plaintext fallback and a runtime ephemeral passphrase. Recovery, credential provisioning, policy adoption and later applies remain explicit operator operations. Neither shell entry, checks nor NixOS rebuilds apply the tailnet configuration.

## Consequences

The repository can validate staged and synthetic enabled configurations without pretending hosts are enrolled. Pure checks cannot verify actual credentials, Tailscale policy-engine acceptance, tag cardinality, network isolation, boot or recovery. Native tests/mocks and a local-only `terraform_data` encryption fixture are not tested installations or a live tailnet.

Tailnet policy replacement affects every existing member/device; non-tailnet LAN/public access is unaffected. MagicDNS is also tailnet-wide and must be reviewed before apply. Tagged identities have different ownership/expiry behavior from user-owned personal devices. Per-device key creation/delivery and protected state/key backups are bootstrap responsibilities, not reasons to put reusable administration credentials on fleet hosts.

Only separately authorized commissioning/activation can enroll a real host. Preserve existing access/rollback/recovery and Bastion NAS boundaries. See [procedure, current inventory and limitations](../tailscale.md), [research](../research.md#staged-tailscale--opentofu--2026-09-10), and [validation](../validation.md).
