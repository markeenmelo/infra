# ADR 0006 — Preserve SOPS password delivery

- Status: accepted
- Date: 2026-09-09
- Amends ADR 0005's manual runtime password-file contracts

## Context

The existing ThinkPad already uses SOPS for its password hash. Replacing this with an unprovisioned `/persist/secrets` contract loses an established delivery mechanism. The previous repository has one encrypted host file and a dedicated ThinkPad age recipient, but no supplied server host ciphertext or verified dedicated identities. Infrastructure evaluation must not invent credentials, rotate identities or imply those other hosts are ready.

## Decision

Add the previous `sops-nix` pin without moving any existing dependency. Its NixOS module is imported into a class-checked deferred `secrets` capability, consumed by `access`. The installer uses each target's own `pkgs`; no input injection or global overlay is introduced.

Replace `fleet.access.passwordFile` with `passwordSecrets`, a typed account-to-declared-SOPS-secret mapping. Null/missing bindings remain explicit commissioning blockers and locked candidate accounts, never guessed filesystem contracts. Real users/UIDs are still host facts. Each password secret must be root-only mode `0400`, `neededForUsers = true`, and the account's sole credential source via its `.path` in `/run/secrets-for-users`. Keep immutable users, locked root, key-only non-root SSH and password sudo.

Use a separately provisioned dedicated age identity at a typed string path directly under early-mounted `/persist/var/lib/sops-nix/`. Disable automatic identity generation and implicit SSH/GPG imports. Retain the current activation-script user backend and default SOPS ramfs; a backend change requires fresh ordering/persistence research. `fleet.secrets.identityReviewed` records actual custody, recipients, permissions, recovery and early-decryption verification, not successful evaluation.

Copy ThinkPad's existing ciphertext unchanged and retain its exact public recipient rule. The whole file is preserved for MAC compatibility, including the encrypted Wi-Fi value, but **at initial integration only the password was declared for decryption**. Subsequent Wi-Fi and Tailscale declarations are separate reviewed capabilities; see [current status](../hosts.md#current-status). Do not import unrelated Tailscale/OpenTofu material, enable the old Wi-Fi agent, or expand recipients. Other hosts retained null identity/credential facts at that checkpoint. Nothing depends on the old repository's filesystem at evaluation/runtime.

## Shared-password amendment — 2026-09-11

The user explicitly selected the existing ThinkPad `marcos` password for ThinkPad, Racknerd and Bastion, authorizing only local in-memory extraction/re-encryption, not activation. A separate **password-only YAML** source, `secrets/shared/marcos-password.yaml`, now supplies the common account policy. It was MAC/equality-verified using the existing operator recovery identity without exposing plaintext or exporting private keys. The original ThinkPad password/Wi-Fi file and every existing host recipient rule remain intact; the retained old password entries are no longer selected.

The shared source currently permits only the verified operator, ThinkPad and Racknerd recipients. Keep distinct host identities. Typed `fleet.secrets.ageRecipient` records each known host's public identity; missing/unlisted recipients or a missing key-file binding prevent password-secret declaration, retain the locked candidate account and block commissioning. A built check compares the YAML recipients to the common module's explicit public policy; it is required alongside structural checks and both-track early-users manifests. No YAML parser is added to Nix evaluation and no decrypted material enters Nix.

At this amendment's initial checkpoint, Bastion remained blocked until its distinct recipient was verified and added to the rule/ciphertext and Nix policy. The separately authorized **2026-09-11/12 Bastion preparation** now completes that membership and verifies dedicated-key decryption plus the temporary account's password installation. Original host ciphertext remains unchanged. The operator declined recovery preparation for the new identity, so `identityReviewed` and host readiness remain false; no baseline was activated. Racknerd's unverified early delivery/recovery stays unverified. Shared credentials increase the compromise/rotation scope; they do not permit password SSH or passwordless sudo. These records do not authorize future credential operations or deployment.

## Consequences

Encrypted password hashes may live in Git and the Nix store; decrypted hashes and private identities may not. The private identity itself needs protected durable storage and recovery custody; impermanence is not encryption. Runtime paths and ciphertext metadata do not prove a valid hash, matching private identity or working sudo.

Both-track fixtures evaluate early password ordering, target-package sourcing and unsafe/missing-credential rejection. Checks build upstream users manifests without decryption. A separate structural/recipient check catches accidental plaintext payloads and rule drift, not cryptographic validity. No fixture can decrypt, install or deploy a system.

At initial integration, every real identity review flag and host readiness remained false. Later evidence-backed commissioning and access reviews are recorded in [current host status](../hosts.md#current-status); they are not authorized by this ADR alone. ThinkPad's pre-transition manifest included an implicit SSH identity; this repository intentionally relies only on the dedicated age identity, verified before activation. A server still using root-only SSH requires a separately authorized staged transition. Boot/migration/network/recovery gates remain in force.

See [secret inventory/procedure](../../secrets/README.md), [host transition checklist](../hosts.md), [research](../research.md), and [validation](../validation.md). No credential generation, decryption, rotation, remote activation or reboot is authorized by this decision.
