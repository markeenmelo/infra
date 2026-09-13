# Encrypted credentials

Only SOPS ciphertext and verified **public** recipients belong in this directory. Never add passwords, plaintext hashes, private keys, decrypted files or editor backups.

Run `bash scripts/secrets/check.sh` before staging encrypted files or evaluating the flake: it checks YAML shape, encrypted payloads and exact recipients without decrypting, and Nix copies tracked files into the public store. Neither shell entry, evaluation nor any check decrypts anything.

## What is selected

`.sops.yaml` has exact per-file rules and no catch-all: a shared password file, three ThinkPad host files and two retained Racknerd files. Recipients are the operator, ThinkPad, and — still, pending rotation — the server identities.

Only ThinkPad selects secrets: the shared password hash, `wifi-psk` from `hosts/thinkpad.yaml`, the campus credentials in `hosts/thinkpad-senecanet.yaml`, and the prepared enrollment key in `hosts/thinkpad-tailscale.yaml`. Both servers select none, so they need no age identity — they use the locked-password `deploy` account with reviewed public SSH keys.

`hosts/thinkpad.yaml` holds both `marcos-password-hash` (retained, unselected) and `wifi-psk`. Keep it intact: hand-removing an entry invalidates its MAC.

**Pending, operator-run:** removing a host from the Nix recipient list does not revoke anything. Retiring the server recipients needs a private `sops rotate --in-place --rm-age ...` over the affected files plus the matching `.sops.yaml` and `modules/access/administrators.nix` edits, committed together. Old Git objects, backups and generations stay decryptable by the old keys, so that is re-encryption, not password rotation.

## How delivery works

- **Passwords:** `fleet.access.passwordSecrets` maps an account to a declared `sops.secrets` name. Declare the hash with `neededForUsers = true`; `hashedPasswordFile` then reads the secret's `.path`, normally `/run/secrets-for-users/NAME`, root-only `0400` on SOPS' ramfs. Nix never evaluates a hash. A null or undeclared name locks the account and blocks commissioning — that is the intended failure, not something to work around.
- **Identity:** a host with selected secrets needs a private age identity as a runtime string path directly on early-mounted `/persist` (`/persist/var/lib/sops-nix/key.txt`), root-owned `0600` under a root-owned `0700` parent, with recovery copies outside Git. Never bind `/var/lib/sops-nix` to reach it, persist `/run/secrets*`, generate keys implicitly or import SSH identities. Disk persistence is not encryption.
- **Wi-Fi:** `wifi-psk` lands root-only `0400` under `/run/secrets`; the generated NetworkManager profiles and escaped environment stay root-only under `/run`. Never persist them, never inspect them with `nmcli --show-secrets` or shell tracing, and never disable campus CA or domain validation to compensate for a bad credential.
- **Tailscale:** enrollment uses `/run/secrets/NAME` at `0400` with `neededForUsers = false` and `restartUnits = [ "fleet-tailscale.service" ]`, selected by name in `fleet.tailscale.authKeySecret` — arbitrary paths are rejected, and the unit passes only a file reference. Tailnet OAuth credentials and the OpenTofu state passphrase are operator-runtime secrets, never host inputs; see [tailscale](../.agents/skills/tailscale/SKILL.md).

## Editing

Use a private interactive terminal with your reviewed identity, never agent tools:

```sh
sops edit secrets/hosts/thinkpad-senecanet.yaml
```

Keep the existing keys, recipients and metadata and let SOPS update the MAC. Use nonempty single-line scalars, not literal blocks. Use protected temporary storage with no editor swap or backup files and no cloud or AI editor integration.

A new encrypted source needs: an exact `.sops.yaml` rule with verified recipients, the `sops.secrets.NAME` declaration in the owning module under `modules/`, and its selection in the relevant `fleet.*` option. `secrets/hosts/thinkpad-senecanet.yaml` still uses `__SET_SENECA_IDENTITY_LOCALLY__` / `__SET_SENECA_PASSWORD_LOCALLY__` markers when unprovisioned; the runtime adapter rejects either marker, so leave `fleet.wifi.senecaSopsFile` null rather than selecting an unfilled file.

Set `fleet.secrets.identityReviewed` only after verifying permissions, custody, recovery and real early decryption with independent console access. A structural check is not a decryption, login or recovery test, and never obtain key material merely to record a review.
