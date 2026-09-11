# Encrypted host credentials

Only SOPS ciphertext and verified **public** recipients belong here. Never add passwords, plaintext password hashes, private keys, decrypted files or editor backups. See [ADR 0006](../docs/adr/0006-sops-password-delivery.md).

## Current inventory

| Host | Ciphertext | Dedicated identity | Status |
|---|---|---|---|
| thinkpad | `hosts/thinkpad.yaml`, unchanged password/PSK ciphertext; `hosts/thinkpad-senecanet.yaml`, filled locally and selected | `/persist/var/lib/sops-nix/key.txt`, root-owned `0600`, parent `0700` verified 2026-09-10 | Private MAC/recipient/decryption and installed early password/PSK binding checks passed; tested independent recovery is operator-confirmed and identity review acknowledged. New-boot delivery and campus authentication remain untested |
| racknerd | `hosts/racknerd.yaml`, operator-supplied existing password hash via `sops edit`; enrollment file not yet created | `/persist/var/lib/sops-nix/key.txt`, authorized dedicated identity; root `0600`, parent `0700` | Canary passed; operator attested custody/recovery after declining the recovery test, so `identityReviewed` is acknowledged; real early decryption is accepted at first activation |
| bastion | None supplied | No identity observed at the previous prepared path | Null facts and commissioning blockers; no new account password invented |
| dino | None supplied | Unverified; unreachable during this follow-up | Both marcos and ian bindings remain null and block commissioning |

The ThinkPad file contains encrypted `marcos-password-hash` **and** `wifi-psk`. Keep it intact: removing entries without authorized SOPS editing invalidates its MAC. Both are now declared: the password remains early/root-only; `wifi-psk` supplies native root-owned runtime NetworkManager profiles through a private environment adapter. The old file-secret agent and Noctalia patch are not imported. SenecaNET identity/password use a separate encrypted file, filled privately by the operator and now selected after successful MAC/decryption and marker/format checks; see [Wi-Fi procedure](../docs/desktop.md#wi-fi-credentials). This does not prove the campus account/password or server-certificate policy works on the real network. Do not delete/edit ciphertext fields by hand.

`.sops.yaml` preserves the previous exact ThinkPad rule and has separate exact rules for `secrets/hosts/thinkpad-senecanet.yaml` and the prepared `secrets/hosts/thinkpad-tailscale.yaml`, using the **same operator + dedicated ThinkPad public recipients**. The operator has now supplied the enrollment file via `sops edit`; ThinkPad's unactivated candidate selects it. There is no catch-all, recipient expansion, new identity or key rotation. Initial creation encrypted only public replacement markers without decrypting the existing password/PSK file. The later **2026-09-10 operator-run private audit** verified both filled ciphertext files in memory; neither ciphertext was modified by that audit or this commissioning change. See [partial preflight evidence](../docs/hosts.md#partial-commissioning-preflight-2026-09-10-utc).

## Racknerd provisioning checkpoint

The [authorized access bootstrap](../docs/hosts.md#authorized-access-bootstrap-and-sops-preparation) now provides working marcos key login and operator-tested password sudo while retaining root SSH and the old generation. Racknerd's newly generated dedicated identity has the verified public recipient recorded as `&racknerd` in `.sops.yaml`. Its exact `hosts/racknerd.yaml` and `hosts/racknerd-tailscale.yaml` rules include only that recipient and the existing operator. ThinkPad recipients/ciphertext remain unchanged.

The operator supplied the existing marcos password hash as encrypted `marcos-password-hash` via regular `sops edit`; `just secret-check` validated the ciphertext/recipients without decryption, and the unactivated candidate delivers it as the early root-only credential. No account hash, private identity or real credential was returned to the agent. The encrypted recovery copy is operator-saved but its recovery test was declined; `identityReviewed` records the explicit attestation instead. Racknerd's commissioning reviews are recorded in [the host inventory](../docs/hosts.md#commissioning-reviews-and-ready-candidate-2026-09-10). The separate exact `tag:fleet-racknerd` enrollment key (`tailscale-auth-key`) is still to be provisioned near its own rollout; never reuse ThinkPad's key or recipients.

## Runtime boundary

`fleet.access.passwordSecrets` maps known accounts to declared `sops.secrets` names. A null or undeclared name locks that candidate account and **blocks commissioning**, rather than pointing to a nonexistent manual hash file. The candidate must not be activated in that state; installed passwords are untouched.

Declare password hashes with `neededForUsers = true`. Account `hashedPasswordFile` values come from the secret's `.path`, normally `/run/secrets-for-users/NAME`, root-only mode `0400`, in SOPS' default ramfs. Password values/hashes are never evaluated by Nix. The ordinary activation-script account backend installs these secrets before creating immutable users. Authenticated sudo with password fallback and key-only non-root SSH remain mandatory fleet policy; ThinkPad additionally permits explicitly requested fingerprint sudo without changing server/SSH/recovery policy.

The private age identity is a **runtime string path**, directly on early-mounted `/persist`. Parent must be root-owned `0700`, key root-owned `0600` (or stricter), with protected recovery copies outside Git. Do not bind `/var/lib/sops-nix` merely to reach it, persist `/run/secrets*`, auto-generate keys or import SSH identities implicitly. Disk persistence is not encryption: review physical access/backups on each host.

## Wi-Fi provisioning boundary

`wifi-psk` is root-owned `0400` under `/run/secrets`; the native profiles and escaped environment remain root-only under `/run`. Never persist these outputs or inspect them with `nmcli --show-secrets`, agent logs or shell tracing. Secret changes request ordered restarts of the environment/profile units during a later authorized activation.

### Fill the SenecaNET placeholders locally

The separate `hosts/thinkpad-senecanet.yaml` **originally** contained these encrypted public markers. The operator has now replaced both, and a private audit verified their replacement before selecting the file. Retain this procedure for provisioning/replacement; never restore markers into a selected live source:

| Key | Replace this marker with |
|---|---|
| `seneca-identity` | Replace `__SET_SENECA_IDENTITY_LOCALLY__` with your username **before `@`**, without whitespace |
| `seneca-password` | Replace `__SET_SENECA_PASSWORD_LOCALLY__` with your campus password |

From the repository root in the locked shell, use your reviewed identity and a **private interactive terminal**, not agent tools:

```sh
sops edit secrets/hosts/thinkpad-senecanet.yaml
```

Follow the secure editor/identity workflow below: protected temporary storage, no swap/backups, no AI/cloud editor integration or plaintext repository files. Preserve the keys, recipients and SOPS metadata; let SOPS update encryption and its MAC. Use nonempty single-line scalars, not literal blocks with trailing newlines. Do not change the existing password/PSK YAML or relax private-identity permissions to make editing work.

After **both** markers have been replaced and the file reviewed, select it inside the existing `fleet.hosts.thinkpad.module` body in `modules/desktop/thinkpad.nix` (already done for the audited ThinkPad file):

```nix
fleet.wifi.senecaSopsFile = ../../secrets/hosts/thinkpad-senecanet.yaml;
```

Until then, leave the option's default **`null`**: no campus profile is emitted and commissioning remains blocked. The runtime adapter also rejects either marker in any credential field if the file is selected prematurely; the shared environment/profile preparation then fails, including MN-Home delivery. Do not select an unfilled file just to remove the null blocker. Run `just secret-check` before staging and `just check` after the reviewed change.

The actual Wi-Fi manifest and separate `senecanet-template-manifest` checks validate encrypted key selection only. The latter can pass against **markers** and is never proof of valid credentials, decryption or readiness.

Never disable Seneca's CA/domain validation to compensate for missing credentials. Back up/reconcile duplicate old profiles deliberately before activation, then test password delivery and server-certificate rejection on the real network under separate authorization.

## Tailscale enrollment (ThinkPad key supplied; candidate not activated)

The operator supplied `hosts/thinkpad-tailscale.yaml` through private `sops edit`; no plaintext key was obtained by the agent. Its exact rule reuses existing recipients, and structural checks passed before staging. [Private provisioning](../docs/tailscale.md#thinkpad-auth-key-preparation) is complete for ThinkPad; runtime dedicated-key decryption and enrollment remain unverified. Each enabled host will need either a verified existing node identity (`preserve`) or its own reviewed short-lived, single-use, non-ephemeral, exact-tag auth key delivered by a declared SOPS secret (`auth-key`). Host tags are not unique constraints: never issue another device ThinkPad's privileged tag. Do not install tailnet-administration OAuth credentials on a host.

Use ordinary `/run/secrets/NAME`, root-only `0400`, `neededForUsers = false`, and `restartUnits = [ "fleet-tailscale.service" ]`. Select the secret by name in `fleet.tailscale.authKeySecret`; arbitrary runtime/store key paths are not accepted. The owning unit passes only a file reference to the CLI. Preserve daemon identity in the reviewed root-only `/persist/var/lib/tailscale` backing. A consumed key need not remain delivered once durable identity has been verified and the host is switched to `preserve`; never hand-edit encrypted payloads/MACs.

Tailnet API credentials and the OpenTofu recovery passphrase are separate operator-runtime secrets, not NixOS/SOPS host inputs. Keep local state/plans/provider working data outside Git/Nix store with enforced encryption and independent recovery. The operator-supplied public tailnet ID is recorded in `tofu/tailscale/tailnet.json`; this is not a secret or proof of API access. The operator privately provisioned a read-only OAuth client and state passphrase, reports successful imports/planning, and confirmed independent passphrase retrieval plus offline backup recovery. The agent checked only private file permissions and encrypted envelopes; no credential value or decrypted state/plan was obtained. Only ThinkPad enrollment ciphertext has now been supplied; no new recipient was added. The operator subsequently confirmed the separate minimal write scopes and freshly reviewed matching policy-only plan, then reported a successful apply (0 added, 1 changed, 0 destroyed). The operator subsequently confirmed no-drift verification, post-apply independent recovery and updated/checked protected backups. The retained ThinkPad **host-state** backup and key provisioning were separately operator-confirmed. The candidate declares root-only `/run/secrets/tailscale-auth-key` with `fleet-tailscale.service` restart ordering; actual delivery remains untested. The [policy-only procedure](../docs/tailscale.md#policy-only-apply-workflow) documents the required posture-write dependency and retains DNS read-only. Keep the read-only client unchanged and the same state passphrase; use those read-only credentials privately for non-saving `just tailnet verify`. No credential values are needed by the agent. The synthetic fixture's encrypted Wi-Fi key selection is **not** a Tailscale credential or enrollment test.

## Safe operator workflow

The locked shell supplies `sops`, `age` and `yq` for reviewed maintenance. Shell entry, `just secret-check` and `just check` do not decrypt anything or contact targets.

1. Recover/verify existing identities and intended per-host password credentials under **separate authorization**. Do not print/export hashes or keys through agent tools, command arguments, shell history or logs. Do not copy ThinkPad ciphertext to other hosts or widen its recipients as a shortcut.
2. If a host needs an identity, provision a distinct one and verify its public recipient through a trusted channel, with recovery custody established. No generation or provisioning is automatic. Add only its exact host-file rule, operator recovery access and verified host recipient.
3. In a secure interactive SOPS editor, preserve the intended existing password hash or explicitly approve a new password; use protected temporary storage and no plaintext editor swap/backup files. Do not run decryption via this agent to obtain the hash. Never use `builtins.readFile` on a runtime secret, `hashedPassword` with a real hash, or private-key path literals as Nix inputs.
4. Add the encrypted host source and `sops.secrets.NAME` declaration to a top-level module under `modules/`; select it in `fleet.access.passwordSecrets.USER` and set the verified `fleet.secrets.ageKeyFile` string. No dependency on the old repository remains.
5. **Before staging**, run `just secret-check` and inspect the diff securely; stage only intended ciphertext/public rules/code. The structural check rejects ambiguous YAML (multiple documents/duplicate keys), accidental plaintext payloads and recipient-rule drift, not an invalid MAC/hash, missing private identity or broken login. `just secret-check-tests` exercises malformed copies in a temporary local directory without touching host state. Nix's both-track manifest builds check selected keys without decrypting. Never add a Git textconv that reveals secrets during agent diff review.
6. With independent console/recovery access and separate host-operation authorization, verify identity permissions/custody, early decryption, preserved password sudo, login and reboot behavior. Only then acknowledge `fleet.secrets.identityReviewed` and the other real migration/access/boot flags. Servers first need a staged non-root access transition on their current configuration. This integration is not that transition.

No plaintext passwords/hashes or private identities were copied into this repository. The operator filled campus values privately, then explicitly authorized and locally ran an in-memory decryption/MAC/value-binding audit with the dedicated identity and isolated empty HOME. Only metadata/booleans were returned; no plaintext files or fallback identities were used. No agent credential editing, recipient/key changes, live profile change, state migration, deployment or reboot occurred. The operator subsequently confirmed tested independent recovery. Together with the private audit and reviewed early mount/activation ordering, the existing identity review is now acknowledged; new-root boot/delivery acceptance remains outstanding. No key material was obtained to record that confirmation.
