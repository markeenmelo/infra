# Encrypted credentials

Only SOPS ciphertext and verified **public** recipients belong in this directory. Never add passwords, plaintext hashes, private keys, decrypted files or editor backups.

There is no automated ciphertext guard. Before staging an encrypted file or evaluating the flake, read it and confirm by eye that the YAML is a single document with no duplicate or merge keys, that every value is an `ENC[AES256_GCM,...]` payload, and that its recipients match exactly one `.sops.yaml` creation rule. Nix copies tracked files into the public store. Neither shell entry nor evaluation decrypts anything.

## What is selected

`.sops.yaml` has exact per-file rules and no catch-all: a shared password file, three ThinkPad host files and two retained Racknerd files. Recipients are the operator, ThinkPad, and — still, pending rotation — the server identities.

Only ThinkPad selects secrets: the shared password hash and the prepared enrollment key in `hosts/thinkpad-tailscale.yaml`. Both servers select none, so they need no age identity — they use the locked-password `deploy` account with reviewed public SSH keys.

`hosts/thinkpad.yaml`'s `wifi-psk` and both campus credentials in `hosts/thinkpad-senecanet.yaml` are retained but **unselected**: declarative Wi-Fi credential delivery was removed along with the runtime adapter that materialized them, so ThinkPad Wi-Fi profiles are now created by hand in NetworkManager. The files stay encrypted and tracked; nothing reads them.

`hosts/thinkpad.yaml` holds both `marcos-password-hash` (retained, unselected) and `wifi-psk`. Keep it intact: hand-removing an entry invalidates its MAC.

**Pending, operator-run:** removing a host from the Nix recipient list does not revoke anything. Retiring the server recipients needs a private `sops rotate --in-place --rm-age ...` over the affected files plus the matching `.sops.yaml` and `modules/access/administrators.nix` edits, committed together. Old Git objects, backups and generations stay decryptable by the old keys, so that is re-encryption, not password rotation.

## How delivery works

- **Passwords:** `fleet.access.passwordSecrets` maps an account to a declared `sops.secrets` name. Declare the hash with `neededForUsers = true`; `hashedPasswordFile` then reads the secret's `.path`, normally `/run/secrets-for-users/NAME`, root-only `0400` on SOPS' ramfs. Nix never evaluates a hash. A null or undeclared name locks the account and blocks commissioning — that is the intended failure, not something to work around.
- **Identity:** a host with selected secrets needs a private age identity as a runtime string path directly on early-mounted `/persist` (`/persist/var/lib/sops-nix/key.txt`), root-owned `0600` under a root-owned `0700` parent, with recovery copies outside Git. Never bind `/var/lib/sops-nix` to reach it, persist `/run/secrets*`, generate keys implicitly or import SSH identities. Disk persistence is not encryption.
- **Wi-Fi:** nothing is delivered any more. Credentials entered by hand live in NetworkManager's own `system-connections` store, which stays persisted and root-only `0700`. Never inspect them with `nmcli --show-secrets` or shell tracing, and never disable campus CA or domain validation to compensate for a bad credential.
- **Tailscale:** enrollment declares `/run/secrets/NAME` at `0400` with `neededForUsers = false`, selected by name in `fleet.tailscale.authKeySecret` — arbitrary paths are rejected. No unit consumes it: the reconciler that enrolled and tagged the client was removed, so `tailscaled` runs but never enrolls itself, and enrollment is now a manual `tailscale up` on the host. Tailnet OAuth credentials and the OpenTofu state passphrase are operator-runtime secrets, never host inputs; see [tailscale](../.agents/skills/tailscale/SKILL.md).

## Editing

Use a private interactive terminal with your reviewed identity, never agent tools:

```sh
sops edit secrets/hosts/thinkpad-senecanet.yaml
```

Keep the existing keys, recipients and metadata and let SOPS update the MAC. Use nonempty single-line scalars, not literal blocks. Use protected temporary storage with no editor swap or backup files and no cloud or AI editor integration.

A new encrypted source needs: an exact `.sops.yaml` rule with verified recipients, the `sops.secrets.NAME` declaration in the owning module under `modules/`, and its selection in the relevant `fleet.*` option. `secrets/hosts/thinkpad-senecanet.yaml` still holds the unprovisioned `__SET_SENECA_IDENTITY_LOCALLY__` / `__SET_SENECA_PASSWORD_LOCALLY__` markers; nothing rejects them any more, so never select that file until both are replaced.

Set `fleet.secrets.identityReviewed` only after verifying permissions, custody, recovery and real early decryption with independent console access. Reading a file is not a decryption, login or recovery test, and never obtain key material merely to record a review.
