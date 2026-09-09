# Encrypted host credentials

Only SOPS ciphertext and verified **public** recipients belong here. Never add passwords, plaintext password hashes, private keys, decrypted files or editor backups. See [ADR 0006](../docs/adr/0006-sops-password-delivery.md).

## Current inventory

| Host | Ciphertext | Dedicated identity | Status |
|---|---|---|---|
| thinkpad | `hosts/thinkpad.yaml`, byte-for-byte reused from the previous repository and matching its running activation manifest input | `/persist/var/lib/sops-nix/key.txt`, previously provisioned | Password/PSK declarations restored; campus credentials absent; fresh custody, recipient/decryption, recovery and boot review pending |
| racknerd / bastion | None supplied | No identity observed at the previous prepared path | Null facts and commissioning blockers; no new account password invented |
| dino | None supplied | Unverified; unreachable during this follow-up | Both marcos and ian bindings remain null and block commissioning |

The ThinkPad file contains encrypted `marcos-password-hash` **and** `wifi-psk`. Keep it intact: removing entries without authorized SOPS editing invalidates its MAC. Both are now declared: the password remains early/root-only; `wifi-psk` supplies native root-owned runtime NetworkManager profiles through a private environment adapter. The old file-secret agent and Noctalia patch are not imported. SenecaNET identity/password are still absent and block campus provisioning; see [Wi-Fi procedure](../docs/desktop.md#wi-fi-credentials). Do not delete/edit ciphertext fields by hand.

`.sops.yaml` preserves the previous exact ThinkPad rule (operator + dedicated host recipient), without the unrelated OpenTofu/Tailscale rule or a catch-all granting every host access. No recipient or identity was generated, rotated or re-encrypted for this integration.

## Runtime boundary

`fleet.access.passwordSecrets` maps known accounts to declared `sops.secrets` names. A null or undeclared name locks that candidate account and **blocks commissioning**, rather than pointing to a nonexistent manual hash file. The candidate must not be activated in that state; installed passwords are untouched.

Declare password hashes with `neededForUsers = true`. Account `hashedPasswordFile` values come from the secret's `.path`, normally `/run/secrets-for-users/NAME`, root-only mode `0400`, in SOPS' default ramfs. Password values/hashes are never evaluated by Nix. The ordinary activation-script account backend installs these secrets before creating immutable users. Authenticated sudo with password fallback and key-only non-root SSH remain mandatory fleet policy; ThinkPad additionally permits explicitly requested fingerprint sudo without changing server/SSH/recovery policy.

The private age identity is a **runtime string path**, directly on early-mounted `/persist`. Parent must be root-owned `0700`, key root-owned `0600` (or stricter), with protected recovery copies outside Git. Do not bind `/var/lib/sops-nix` merely to reach it, persist `/run/secrets*`, auto-generate keys or import SSH identities implicitly. Disk persistence is not encryption: review physical access/backups on each host.

## Wi-Fi provisioning boundary

`wifi-psk` is root-owned `0400` under `/run/secrets`; the native profiles and escaped environment remain root-only under `/run`. Never persist these outputs or inspect them with `nmcli --show-secrets`, agent logs or shell tracing. Secret changes request ordered restarts of the environment/profile units during a later authorized activation.

To provision campus access, use the secure interactive workflow below to add **`seneca-identity`** (username before `@`) and **`seneca-password`** to the existing ThinkPad YAML, preserving its other fields and recipients. Use nonempty single-line scalars, not literal blocks with trailing newlines. Set `fleet.wifi.senecaSopsFile` to that reviewed encrypted file in a top-level ThinkPad contribution only after the fields exist. Its default `null` emits no incomplete SenecaNET profile and adds a commissioning blocker. The actual Wi-Fi manifest check validates selected encrypted keys without decryption; the separate campus template fixture is explicitly not a credential/decryption test.

Never disable Seneca's CA/domain validation to compensate for missing credentials. Back up/reconcile duplicate old profiles deliberately before activation, then test password delivery and server-certificate rejection on the real network under separate authorization.

## Safe operator workflow

The locked shell supplies `sops`, `age` and `yq` for reviewed maintenance. Shell entry, `just secret-check` and `just check` do not decrypt anything or contact targets.

1. Recover/verify existing identities and intended per-host password credentials under **separate authorization**. Do not print/export hashes or keys through agent tools, command arguments, shell history or logs. Do not copy ThinkPad ciphertext to other hosts or widen its recipients as a shortcut.
2. If a host needs an identity, provision a distinct one and verify its public recipient through a trusted channel, with recovery custody established. No generation or provisioning is automatic. Add only its exact host-file rule, operator recovery access and verified host recipient.
3. In a secure interactive SOPS editor, preserve the intended existing password hash or explicitly approve a new password; use protected temporary storage and no plaintext editor swap/backup files. Do not run decryption via this agent to obtain the hash. Never use `builtins.readFile` on a runtime secret, `hashedPassword` with a real hash, or private-key path literals as Nix inputs.
4. Add the encrypted host source and `sops.secrets.NAME` declaration to a top-level module under `modules/`; select it in `fleet.access.passwordSecrets.USER` and set the verified `fleet.secrets.ageKeyFile` string. No dependency on the old repository remains.
5. **Before staging**, run `just secret-check` and inspect the diff securely; stage only intended ciphertext/public rules/code. The structural check rejects ambiguous YAML (multiple documents/duplicate keys), accidental plaintext payloads and recipient-rule drift, not an invalid MAC/hash, missing private identity or broken login. `just secret-check-tests` exercises malformed copies in a temporary local directory without touching host state. Nix's both-track manifest builds check selected keys without decrypting. Never add a Git textconv that reveals secrets during agent diff review.
6. With independent console/recovery access and separate host-operation authorization, verify identity permissions/custody, early decryption, preserved password sudo, login and reboot behavior. Only then acknowledge `fleet.secrets.identityReviewed` and the other real migration/access/boot flags. Servers first need a staged non-root access transition on their current configuration. This integration is not that transition.

No plaintext passwords/hashes or private identities were copied into this repository. No SOPS decrypt/edit/updatekeys, host mutation, deployment or reboot was run.
