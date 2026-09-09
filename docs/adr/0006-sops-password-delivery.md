# ADR 0006 — Preserve SOPS password delivery

- Status: accepted
- Date: 2026-09-09
- Amends ADR 0005's manual runtime password-file contracts

## Context

The existing ThinkPad already uses SOPS for its password hash. Replacing this with an unprovisioned `/persist/secrets` contract loses an established delivery mechanism. The previous repository has one encrypted host file and a dedicated ThinkPad age recipient, but no supplied server/Dino host ciphertext or verified dedicated identities. Infrastructure evaluation must not invent credentials, rotate identities or imply those other hosts are ready.

## Decision

Add the previous `sops-nix` pin without moving any existing dependency. Its NixOS module is imported into a class-checked deferred `secrets` capability, consumed by `access`. The installer uses each target's own `pkgs`; no input injection or global overlay is introduced.

Replace `fleet.access.passwordFile` with `passwordSecrets`, a typed account-to-declared-SOPS-secret mapping. Null/missing bindings remain explicit commissioning blockers and locked candidate accounts, never guessed filesystem contracts. Real users/UIDs are still host facts. Each password secret must be root-only mode `0400`, `neededForUsers = true`, and the account's sole credential source via its `.path` in `/run/secrets-for-users`. Keep immutable users, locked root, key-only non-root SSH and password sudo.

Use a separately provisioned dedicated age identity at a typed string path directly under early-mounted `/persist/var/lib/sops-nix/`. Disable automatic identity generation and implicit SSH/GPG imports. Retain the current activation-script user backend and default SOPS ramfs; a backend change requires fresh ordering/persistence research. `fleet.secrets.identityReviewed` records actual custody, recipients, permissions, recovery and early-decryption verification, not successful evaluation.

Copy ThinkPad's existing ciphertext unchanged and retain its exact public recipient rule. The whole file is preserved for MAC compatibility, including the encrypted Wi-Fi value, but **only the password is declared for decryption**. Do not import unrelated Tailscale/OpenTofu material, enable the old Wi-Fi agent, or expand recipients. Other hosts keep null identity/credential facts. Nothing depends on the old repository's filesystem at evaluation/runtime.

## Consequences

Encrypted password hashes may live in Git and the Nix store; decrypted hashes and private identities may not. The private identity itself needs protected durable storage and recovery custody; impermanence is not encryption. Runtime paths and ciphertext metadata do not prove a valid hash, matching private identity or working sudo.

Both-track fixtures evaluate early password ordering, target-package sourcing and unsafe/missing-credential rejection. Checks build upstream users manifests without decryption. A separate structural/recipient check catches accidental plaintext payloads and rule drift, not cryptographic validity. No fixture can decrypt, install or deploy a system.

Every real identity review flag and host readiness remains false. ThinkPad's current manifest also includes an implicit SSH identity; the candidate intentionally relies only on its previously provisioned dedicated age identity, which must be verified before activation. Servers require a separately authorized staged transition from root-only SSH; Dino's credentials must be recovered when reachable. Boot/migration/network/recovery gates remain in force.

See [secret inventory/procedure](../../secrets/README.md), [host transition checklist](../hosts.md), [research](../research.md), and [validation](../validation.md). No credential generation, decryption, rotation, remote activation or reboot is authorized by this decision.
