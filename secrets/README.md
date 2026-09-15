# Encrypted credentials

Only SOPS ciphertext and verified **public** recipients belong in this directory. Never add passwords, plaintext hashes, private keys, decrypted files or editor backups.

There is no automated ciphertext guard. Before staging an encrypted file or evaluating the flake, read it and confirm by eye that the YAML is a single document with no duplicate or merge keys, that every value is an `ENC[AES256_GCM,...]` payload, and that its recipients match exactly one `.sops.yaml` creation rule. Nix copies tracked files into the public store. Neither shell entry nor evaluation decrypts anything.

## What is selected

`.sops.yaml` has exact rules and no catch-all for `hosts/thinkpad.yaml`, `hosts/thinkpad-senecanet.yaml`, `tailscale/operator.yaml`, `porkbun/operator.yaml` and `web/operator.yaml`. The host files have exactly the existing operator and ThinkPad public recipients. The three operator files have only the existing operator recipient and are never selected by sops-nix. Removed ciphertext may still remain decryptable by its historical recipients in old Git objects, backups and generations.

Only ThinkPad selects secrets: `marcos-password-hash` and `wifi-psk` from `hosts/thinkpad.yaml`, plus `seneca-identity` and `seneca-password` from `hosts/thinkpad-senecanet.yaml`. Both servers select none, so they need no age identity — they use the locked-password `deploy` account with reviewed public SSH keys.

`modules/desktop/networkmanager.nix` selects the Wi-Fi credentials for native MN-Home and SenecaNET profiles. Their existing encrypted values were confirmed current by the operator; this is not a decryption or connection test. Keep `hosts/thinkpad.yaml` intact: hand-removing either its password hash or PSK invalidates its MAC.

## How delivery works

- **Passwords:** `fleet.access.passwordSecrets` maps an account to a declared `sops.secrets` name. Declare the hash with `neededForUsers = true`; `hashedPasswordFile` then reads the secret's `.path`, normally `/run/secrets-for-users/NAME`, root-only `0400` on SOPS' ramfs. Nix never evaluates a hash. A null or undeclared name locks the account — that is the intended failure, not something to work around.
- **Identity:** a host with selected secrets needs a private age identity as a runtime string path directly on early-mounted `/persist` (`/persist/var/lib/sops-nix/key.txt`), root-owned `0600` under a root-owned `0700` parent, with recovery copies outside Git. Never bind `/var/lib/sops-nix` to reach it, persist `/run/secrets*`, generate keys implicitly or import SSH identities. Disk persistence is not encryption.
- **Wi-Fi:** SOPS delivers three root-only `0400` files under `/run/secrets`. A Nix-built runtime adapter validates and escapes them for both systemd EnvironmentFile and GLib keyfile syntax, atomically writing a `0600` environment file under root-only `/run/fleet-wifi-environment`. Native `ensureProfiles` then generates root-only MN-Home and SenecaNET profiles under `/run/NetworkManager/system-connections` and reloads NetworkManager. Secret changes restart the adapter and profile unit in order; preparation failure blocks regeneration. Only ciphertext, credential-free templates and runtime paths enter Nix/the store. Raw SOPS template substitution is not a replacement for this escaping.
- **Wi-Fi editing:** use private SOPS editing for credentials and Nix for these two profiles. Use nonempty single-line values without control characters other than tabs; campus identity is the username before `@`, with no whitespace. Spaces and punctuation in passwords are preserved. Manual profiles for other networks still live in persisted, root-only `0700` `system-connections`. Never inspect credentials with `nmcli --show-secrets` or shell tracing, and never disable campus CA or domain validation to compensate for a bad credential. SenecaNET follows [Seneca's published PEAP/MSCHAPv2, system-CA and domain policy](https://students.senecapolytechnic.ca/spaces/186/it-services/wiki/view/1030/senecanet).

## Tailnet operator custody

`tailscale/operator.yaml` is the unchanged copy of the reviewed operator-local ciphertext. Its four encrypted fields are `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`, `TAILSCALE_TAILNET` and `TF_VAR_state_passphrase`. The only recipient is the existing operator age key. Never add a host recipient, select this file in sops-nix, put plaintext in Nix/task outputs, or deliver the OAuth credential to a host. SecretSpec, dotenv and shell-entry secret loading stay disabled.

Only explicitly invoked operator processes decrypt it. OpenTofu state and saved plans use enforced PBKDF2/AES-GCM encryption and private local storage; provider debug logs and plaintext output are unsafe even when state is encrypted. Keep independently recoverable backups of the age identity, passphrase and encrypted backend. Ciphertext in Git alone cannot recover them. Follow the [Tailscale procedure](../.agents/skills/tailscale/SKILL.md) for private extraction of a single-use enrollment key, not recurring host secret delivery. No existing credential revocation is authorized.

## Web and Porkbun commissioning

The [reverse-proxy procedure](../.agents/skills/reverse-proxy/SKILL.md) keeps all web/SSH-cutover gates off until separately commissioned. No server ciphertext or host recipient has been fabricated. Before selecting server secrets, verify dedicated host age custody/recovery and add an exact rule with only the operator and that verified host. Select root-owned `0400` SOPS files through the owning concern's typed secret-name options; systemd credentials deliver them privately at runtime. Never put Authelia password hashes, bouncer keys or DNS credentials into Nix or logs.

`porkbun/operator.yaml` contains operator-only encrypted `REPLACE_ME` placeholders, explicitly requested for private preparation. Replace all three fields before any OpenTofu use: `PORKBUN_API_KEY`, `PORKBUN_SECRET_KEY` and an independently recoverable, high-entropy `TF_VAR_state_passphrase` of at least 16 characters, separate from tailnet custody. It is never selected in sops-nix. Proxy Lego uses separate runtime credentials and the distinct names `PORKBUN_API_KEY_FILE` / `PORKBUN_SECRET_API_KEY_FILE`. Treat proxy DNS credentials as broad domain authority unless actual restrictions are verified. A bouncer key must match registration in that host's persisted local CrowdSec database; a SOPS value alone proves nothing.

### Populate the preparation files

Use your private editor through SOPS, never agent tools or a plaintext file in the checkout:

```sh
sops edit secrets/porkbun/operator.yaml
sops edit secrets/web/operator.yaml
```

`web/operator.yaml` is an operator-only preparation bundle, not a host secret source. Every value starts as encrypted `REPLACE_ME`. The `racknerd` and `bastion` sections hold their respective proxy `porkbunApiKey`, `porkbunSecretKey` and `httpBouncerKey`; Racknerd also has `authelia.jwt`, `storage` and `users`. No SMTP fields are needed. Use independently generated cryptographically random values of at least 32 characters for JWT and storage keys. Supply `users` as the complete real Authelia user-directory YAML in one quoted string (use escaped `\n` for line breaks), including privately generated password hashes, groups and email addresses. Leave bouncer placeholders until separately authorized registration supplies the matching local HTTP bouncer keys; arbitrary random strings are not registered keys.

Never select the preparation bundle in sops-nix or add a server recipient to it: that would expose both servers' material. After host age custody/recovery is verified, privately split only each host's required values into its own SOPS file with exactly the operator and that host recipient, then review declarations and selections. Private age identities stay outside Git. Encrypted placeholders are not usable credentials or commissioning evidence; verify every required replacement privately before use. No automated placeholder detection exists.

## Editing

Use a private interactive terminal with your reviewed identity, never agent tools:

```sh
sops edit secrets/hosts/thinkpad-senecanet.yaml
```

Keep the existing keys, recipients and metadata and let SOPS update the MAC. Use nonempty single-line scalars, not literal blocks. Use protected temporary storage with no editor swap or backup files and no cloud or AI editor integration.

A new host-delivered encrypted source needs: an exact `.sops.yaml` rule with verified recipients, the `sops.secrets.NAME` declaration in the owning module under `modules/`, and its selection in the relevant `fleet.*` option. Campus credential delivery requires separate review of current credentials and the published server-certificate policy; neither a runtime path nor a successful build establishes those facts. See the [desktop skill](../.agents/skills/desktop/SKILL.md) for migration, rollback and separately authorized live verification.

Verify a host identity's permissions, custody, recovery and real early decryption with independent console access before relying on it. Reading a file is not a decryption, login or recovery test, and never obtain key material merely to record a review.
