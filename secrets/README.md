# Encrypted credentials

Only SOPS ciphertext and verified **public** recipients belong in this directory. Never add passwords, plaintext hashes, private keys, decrypted files or editor backups.

There is no automated ciphertext guard. Before staging an encrypted file or evaluating the flake, read it and confirm by eye that the YAML is a single document with no duplicate or merge keys, that every value is an `ENC[AES256_GCM,...]` payload, and that its recipients match exactly one `.sops.yaml` creation rule. Nix copies tracked files into the public store. Neither shell entry nor evaluation decrypts anything.

## What is selected

`.sops.yaml` has exact rules and no catch-all for `hosts/thinkpad.yaml`, `hosts/thinkpad-senecanet.yaml` and `tailscale/operator.yaml`. The host files have exactly the existing operator and ThinkPad public recipients. The tailnet source has only the existing operator recipient and is never selected by sops-nix. Removed ciphertext may still remain decryptable by its historical recipients in old Git objects, backups and generations.

Only ThinkPad selects a secret: `marcos-password-hash` from `hosts/thinkpad.yaml`. Both servers select none, so they need no age identity — they use the locked-password `deploy` account with reviewed public SSH keys.

`hosts/thinkpad.yaml`'s `wifi-psk` and both campus credentials in `hosts/thinkpad-senecanet.yaml` are retained but **unselected**: declarative Wi-Fi credential delivery was removed along with the runtime adapter that materialized them, so ThinkPad Wi-Fi profiles are now created by hand in NetworkManager. Keep `hosts/thinkpad.yaml` intact: hand-removing either its selected password hash or unselected PSK invalidates its MAC.

## How delivery works

- **Passwords:** `fleet.access.passwordSecrets` maps an account to a declared `sops.secrets` name. Declare the hash with `neededForUsers = true`; `hashedPasswordFile` then reads the secret's `.path`, normally `/run/secrets-for-users/NAME`, root-only `0400` on SOPS' ramfs. Nix never evaluates a hash. A null or undeclared name locks the account — that is the intended failure, not something to work around.
- **Identity:** a host with selected secrets needs a private age identity as a runtime string path directly on early-mounted `/persist` (`/persist/var/lib/sops-nix/key.txt`), root-owned `0600` under a root-owned `0700` parent, with recovery copies outside Git. Never bind `/var/lib/sops-nix` to reach it, persist `/run/secrets*`, generate keys implicitly or import SSH identities. Disk persistence is not encryption.
- **Wi-Fi:** nothing is delivered any more. Credentials entered by hand live in NetworkManager's own `system-connections` store, which stays persisted and root-only `0700`. Never inspect them with `nmcli --show-secrets` or shell tracing, and never disable campus CA or domain validation to compensate for a bad credential.

## Tailnet operator custody

`tailscale/operator.yaml` is the unchanged copy of the reviewed operator-local ciphertext. Its four encrypted fields are `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`, `TAILSCALE_TAILNET` and `TF_VAR_state_passphrase`. The only recipient is the existing operator age key. Never add a host recipient, select this file in sops-nix, put plaintext in Nix/task outputs, or deliver the OAuth credential to a host. SecretSpec, dotenv and shell-entry secret loading stay disabled.

Only explicitly invoked operator processes decrypt it. OpenTofu state and saved plans use enforced PBKDF2/AES-GCM encryption and private local storage; provider debug logs and plaintext output are unsafe even when state is encrypted. Keep independently recoverable backups of the age identity, passphrase and encrypted backend. Ciphertext in Git alone cannot recover them. Follow the [Tailscale procedure](../.agents/skills/tailscale/SKILL.md) for private extraction of a single-use enrollment key, not recurring host secret delivery. No existing credential revocation is authorized.

## Editing

Use a private interactive terminal with your reviewed identity, never agent tools:

```sh
sops edit secrets/hosts/thinkpad-senecanet.yaml
```

Keep the existing keys, recipients and metadata and let SOPS update the MAC. Use nonempty single-line scalars, not literal blocks. Use protected temporary storage with no editor swap or backup files and no cloud or AI editor integration.

A new host-delivered encrypted source needs: an exact `.sops.yaml` rule with verified recipients, the `sops.secrets.NAME` declaration in the owning module under `modules/`, and its selection in the relevant `fleet.*` option. Keep `secrets/hosts/thinkpad-senecanet.yaml` unselected until its credentials and server-certificate policy are separately reviewed for delivery.

Verify a host identity's permissions, custody, recovery and real early decryption with independent console access before relying on it. Reading a file is not a decryption, login or recovery test, and never obtain key material merely to record a review.
