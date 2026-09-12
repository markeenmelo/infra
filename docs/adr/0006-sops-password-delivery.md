# ADR 0006 — SOPS password delivery

- Status: accepted; supersedes ADR 0005's manual runtime password-file contracts (shared-password amendment 2026-09-11 folded in)
- Date: 2026-09-09

## Context

The existing ThinkPad already uses SOPS for its password hash. Replacing it with an unprovisioned `/persist/secrets` contract would lose an established delivery mechanism. Only ThinkPad had verified ciphertext and a dedicated age recipient; evaluation must not invent credentials, rotate identities or imply other hosts are ready.

## Decision

- Import the previous `sops-nix` pin as a class-checked deferred `secrets` capability consumed by `access`; each target's own `pkgs` installs it. No input injection or global overlay.
- `fleet.access.passwordSecrets` is a typed account-to-declared-SOPS-secret mapping. Null/missing bindings remain explicit commissioning blockers and locked candidate accounts, never guessed filesystem contracts. Real users/UIDs stay host facts. Each password secret is root-only mode `0400`, `neededForUsers = true`, delivered via its `.path` in `/run/secrets-for-users`, and is the account's sole credential source. Immutable users, locked root, key-only non-root SSH and password sudo stay.
- A dedicated persistent age identity lives at a typed string path under early-mounted `/persist/var/lib/sops-nix/`; automatic identity generation and implicit SSH/GPG imports are disabled. `fleet.secrets.identityReviewed` records actual custody, recipients, permissions, recovery and early-decryption verification — not successful evaluation.
- ThinkPad's existing ciphertext is copied unchanged with its exact public recipient rule (the whole file is kept for MAC compatibility, including the encrypted Wi-Fi value). Subsequent Wi-Fi and Tailscale declarations are separately reviewed capabilities. Do not import unrelated material, enable the old Wi-Fi agent or expand recipients.
- **Shared password (amendment):** the user selected the existing ThinkPad `marcos` password for all three hosts, authorizing only local in-memory extraction/re-encryption. A separate password-only YAML (`secrets/shared/marcos-password.yaml`) supplies the common account policy, MAC/equality-verified without exposing plaintext. It permits only the verified operator, ThinkPad and Racknerd recipients; distinct host identities are kept. Typed `fleet.secrets.ageRecipient` records each known host's public identity; missing/unlisted recipients or a missing key-file binding retain the locked candidate account and block commissioning. A built check compares the YAML recipients to the explicit public Nix policy; no YAML parser enters Nix evaluation. Bastion stays blocked until its distinct recipient is verified and deliberately added to both ciphertext and policy. Shared credentials widen compromise/rotation scope and permit neither password SSH nor passwordless sudo.

## Consequences

- Encrypted password hashes may live in Git and the Nix store; decrypted hashes and private identities may not. The private identity needs protected durable storage and recovery custody. Runtime paths and ciphertext metadata prove nothing about a valid hash, matching identity or working sudo.
- Checks cover early password ordering, target-package sourcing, unsafe/missing-credential rejection, structural recipient drift and built upstream users manifests — without decryption ([validation scope](../validation.md)).
- Review/readiness flags change only with recorded evidence in [hosts.md](../hosts.md#current-status).

See [secret inventory and procedure](../../secrets/README.md).
