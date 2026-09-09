# Encrypted host credentials

Only SOPS ciphertext and verified **public** recipients belong here. Never add passwords, plaintext password hashes, private keys, decrypted files or editor backups. See [ADR 0006](../docs/adr/0006-sops-password-delivery.md).

## Current inventory

| Host | Ciphertext | Dedicated identity | Status |
|---|---|---|---|
| thinkpad | `hosts/thinkpad.yaml`, unchanged password/PSK ciphertext; `hosts/thinkpad-senecanet.yaml`, newly encrypted replacement markers only | `/persist/var/lib/sops-nix/key.txt`, previously provisioned | Password/PSK declarations restored; campus values still unfilled/disabled; fresh custody, recipient/decryption, recovery and boot review pending |
| racknerd / bastion | None supplied | No identity observed at the previous prepared path | Null facts and commissioning blockers; no new account password invented |
| dino | None supplied | Unverified; unreachable during this follow-up | Both marcos and ian bindings remain null and block commissioning |

The ThinkPad file contains encrypted `marcos-password-hash` **and** `wifi-psk`. Keep it intact: removing entries without authorized SOPS editing invalidates its MAC. Both are now declared: the password remains early/root-only; `wifi-psk` supplies native root-owned runtime NetworkManager profiles through a private environment adapter. The old file-secret agent and Noctalia patch are not imported. SenecaNET identity/password have a separate encrypted placeholder file, but real values are still absent and campus provisioning remains blocked; see [Wi-Fi procedure](../docs/desktop.md#wi-fi-credentials). Do not delete/edit ciphertext fields by hand.

`.sops.yaml` preserves the previous exact ThinkPad rule and adds one exact rule for `secrets/hosts/thinkpad-senecanet.yaml`, using the **same operator + dedicated ThinkPad public recipients**. There is no catch-all, recipient expansion, new identity or key rotation. Only the public replacement markers were encrypted; the existing password/PSK file was neither decrypted nor modified.

## Runtime boundary

`fleet.access.passwordSecrets` maps known accounts to declared `sops.secrets` names. A null or undeclared name locks that candidate account and **blocks commissioning**, rather than pointing to a nonexistent manual hash file. The candidate must not be activated in that state; installed passwords are untouched.

Declare password hashes with `neededForUsers = true`. Account `hashedPasswordFile` values come from the secret's `.path`, normally `/run/secrets-for-users/NAME`, root-only mode `0400`, in SOPS' default ramfs. Password values/hashes are never evaluated by Nix. The ordinary activation-script account backend installs these secrets before creating immutable users. Authenticated sudo with password fallback and key-only non-root SSH remain mandatory fleet policy; ThinkPad additionally permits explicitly requested fingerprint sudo without changing server/SSH/recovery policy.

The private age identity is a **runtime string path**, directly on early-mounted `/persist`. Parent must be root-owned `0700`, key root-owned `0600` (or stricter), with protected recovery copies outside Git. Do not bind `/var/lib/sops-nix` merely to reach it, persist `/run/secrets*`, auto-generate keys or import SSH identities implicitly. Disk persistence is not encryption: review physical access/backups on each host.

## Wi-Fi provisioning boundary

`wifi-psk` is root-owned `0400` under `/run/secrets`; the native profiles and escaped environment remain root-only under `/run`. Never persist these outputs or inspect them with `nmcli --show-secrets`, agent logs or shell tracing. Secret changes request ordered restarts of the environment/profile units during a later authorized activation.

### Fill the SenecaNET placeholders locally

The separate `hosts/thinkpad-senecanet.yaml` contains encrypted **public markers**, not usable credentials:

| Key | Replace this marker with |
|---|---|
| `seneca-identity` | Replace `__SET_SENECA_IDENTITY_LOCALLY__` with your username **before `@`**, without whitespace |
| `seneca-password` | Replace `__SET_SENECA_PASSWORD_LOCALLY__` with your campus password |

From the repository root in the locked shell, use your reviewed identity and a **private interactive terminal**, not agent tools:

```sh
sops edit secrets/hosts/thinkpad-senecanet.yaml
```

Follow the secure editor/identity workflow below: protected temporary storage, no swap/backups, no AI/cloud editor integration or plaintext repository files. Preserve the keys, recipients and SOPS metadata; let SOPS update encryption and its MAC. Use nonempty single-line scalars, not literal blocks with trailing newlines. Do not change the existing password/PSK YAML or relax private-identity permissions to make editing work.

After **both** markers have been replaced and the file reviewed, add this inside the existing `fleet.hosts.thinkpad.module` body in `modules/desktop/thinkpad.nix`:

```nix
fleet.wifi.senecaSopsFile = ../../secrets/hosts/thinkpad-senecanet.yaml;
```

Until then, leave the option's default **`null`**: no campus profile is emitted and commissioning remains blocked. The runtime adapter also rejects either marker in any credential field if the file is selected prematurely; the shared environment/profile preparation then fails, including MN-Home delivery. Do not select an unfilled file just to remove the null blocker. Run `just secret-check` before staging and `just check` after the reviewed change.

The actual Wi-Fi manifest and separate `senecanet-template-manifest` checks validate encrypted key selection only. The latter can pass against **markers** and is never proof of valid credentials, decryption or readiness.

Never disable Seneca's CA/domain validation to compensate for missing credentials. Back up/reconcile duplicate old profiles deliberately before activation, then test password delivery and server-certificate rejection on the real network under separate authorization.

## Safe operator workflow

The locked shell supplies `sops`, `age` and `yq` for reviewed maintenance. Shell entry, `just secret-check` and `just check` do not decrypt anything or contact targets.

1. Recover/verify existing identities and intended per-host password credentials under **separate authorization**. Do not print/export hashes or keys through agent tools, command arguments, shell history or logs. Do not copy ThinkPad ciphertext to other hosts or widen its recipients as a shortcut.
2. If a host needs an identity, provision a distinct one and verify its public recipient through a trusted channel, with recovery custody established. No generation or provisioning is automatic. Add only its exact host-file rule, operator recovery access and verified host recipient.
3. In a secure interactive SOPS editor, preserve the intended existing password hash or explicitly approve a new password; use protected temporary storage and no plaintext editor swap/backup files. Do not run decryption via this agent to obtain the hash. Never use `builtins.readFile` on a runtime secret, `hashedPassword` with a real hash, or private-key path literals as Nix inputs.
4. Add the encrypted host source and `sops.secrets.NAME` declaration to a top-level module under `modules/`; select it in `fleet.access.passwordSecrets.USER` and set the verified `fleet.secrets.ageKeyFile` string. No dependency on the old repository remains.
5. **Before staging**, run `just secret-check` and inspect the diff securely; stage only intended ciphertext/public rules/code. The structural check rejects ambiguous YAML (multiple documents/duplicate keys), accidental plaintext payloads and recipient-rule drift, not an invalid MAC/hash, missing private identity or broken login. `just secret-check-tests` exercises malformed copies in a temporary local directory without touching host state. Nix's both-track manifest builds check selected keys without decrypting. Never add a Git textconv that reveals secrets during agent diff review.
6. With independent console/recovery access and separate host-operation authorization, verify identity permissions/custody, early decryption, preserved password sudo, login and reboot behavior. Only then acknowledge `fleet.secrets.identityReviewed` and the other real migration/access/boot flags. Servers first need a staged non-root access transition on their current configuration. This integration is not that transition.

No plaintext passwords/hashes or private identities were copied into this repository. Only the public campus replacement markers were newly encrypted, with an isolated empty home and the existing public recipients. No SOPS decrypt/edit/updatekeys, host mutation, deployment or reboot was run.
