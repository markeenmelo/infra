---
name: tailscale
description: Maintain staged Tailscale clients and guarded OpenTofu policy, encrypted state, credentials and recovery without implicit enrollment or live API operations.
---

# Tailscale and OpenTofu

Read `../../../AGENTS.md`, [operator procedure](references/tailscale.md), [current status](../fleet-operations/references/hosts.md#current-status), [ADR 0009](../dendritic-nix/references/adr/0009-tailscale-and-opentofu.md) and the affected `../../../modules/tailscale/` / `../../../tofu/tailscale/` files.

## Procedure

1. Separate local configuration/test work, live policy management and host enrollment. Current policy differs from the earlier operator-reported apply; do not reuse retained plans or interpret old approval as current permission.
2. Preserve the single public tailnet binding, whole-policy ownership and exact ThinkPad-to-servers TCP 22/ICMP grant. Tags are not unique constraints: intended one-device cardinality needs real review. Public/LAN recovery remains independent.
3. Keep one policy writer, protected existing encrypted state/passphrase and default-workspace/provider isolation. No plaintext fallback, debug overrides, silent permission repair, state recreation, repeated imports or automatic apply. Generated provider checksums identify the Nix-built linux_amd64 artifact, not a registry release; review changes rather than silently regenerating them.
4. Credentials belong only in a private runtime process. Existing `tailnet-sops` accepts exactly the OAuth ID/secret and existing passphrase; no task, shell hook or Nix evaluation may decrypt. Follow the reference's minimal read/write scopes, independent recovery and emergency-state preservation procedure.
5. Client rollout remains individually reviewed, with a separately maintained independent oracle. Preserve private state/mount requirements; use file-reference single-use auth keys only in `NeedsLogin`. Reconnect stopped identities with externally bounded bare `up`, never forced resets or preference loss. Native enrollment must not compete with the reconciler.
6. Follow [manual validation](../validate/SKILL.md): native flake checks include mocked reconciliation/provider/wrapper/SOPS tests and synthetic encrypted local state. Do not call real `tailnet` or a daemon for validation.
7. Only with current operation authorization, follow the detailed private-terminal plan/review/apply or per-host activation/acceptance procedure. Non-saving `verify` still contacts the API; statuses are 0 no changes, 2 drift, 1 error. Preserve rollback and independent access.

## Completion

Offline tests are not decryption, enrollment, live policy-engine, traffic, boot or restore tests. Report those boundaries and unresolved runtime acceptance without broadening scope or credentials.
