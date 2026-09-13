# Encrypted credentials

For current local checks, follow [manual validation](../.agents/skills/validate/SKILL.md), including the ciphertext guard before staging/evaluation. The explicitly requested scaffold/install/deploy tasks do not load secrets at evaluation or shell entry. Installation uses independently reviewed private runtime identity staging. The guided `install HOST` interface prompts for paths and derives public identity information locally before the final erasure confirmation; paths stay in the installer child environment and its temporary manifest is removed afterward. It never asks for key contents, decrypts SOPS ciphertext or generates identities. Target contact and installation still require confirmation and full preflight; validation checks never decrypt. Historical results below retain their original dates and do not authorize new operations.

Only SOPS ciphertext and verified **public** recipients belong here. Never add passwords, plaintext password hashes, private keys, decrypted files or editor backups. See [ADR 0006](../.agents/skills/dendritic-nix/references/adr/0006-sops-password-delivery.md).

## Current inventory

Declared sources/bindings are below. **Dated credential, recovery and boot acceptance lives in [current host status](../.agents/skills/fleet-operations/references/hosts.md#current-status)**, including ThinkPad's completed password/Wi-Fi two-boot delivery and the separate unverified Tailscale credential. A declared path or ciphertext is not proof of decryption.

The current candidate selects **`shared/marcos-password.yaml` only on ThinkPad**. Both servers remove `marcos` and password delivery, replacing it with the locked-password `deploy` account and the two reviewed public SSH keys. No password/private key is provisioned for deploy. This configuration-only transition has not changed running accounts or erased credentials. The follow-up candidate also removes server age-key paths/recipients and active SOPS identity-review metadata: there are no selected server secrets, templates or SOPS activation hooks, so no server age key is required or staged for reinstall. Machine ID/SSH identities still require preservation; old age identities and encrypted recovery archives remain off-host recovery material and are not automatically deleted. **Ciphertext/public recipient policy is still unchanged pending the operator-run rotation below**: configuration removal alone has not revoked existing ciphertext access. The dated three-host password evidence below describes the accepted older installations.

| Host | Additional host-specific ciphertext | Dedicated identity binding |
|---|---|---|
| thinkpad | `hosts/thinkpad.yaml` (Wi-Fi plus retained, unselected original password), `hosts/thinkpad-senecanet.yaml`, `hosts/thinkpad-tailscale.yaml` | `/persist/var/lib/sops-nix/key.txt` |
| racknerd | `hosts/racknerd.yaml` retained but unselected; no active enrollment secret | None in the candidate; historical identity/recovery remains protected off-host |
| bastion | None selected; no password, Wi-Fi or enrollment delivery | None in the candidate; historical identity/recovery remains protected off-host |

The ThinkPad file contains encrypted `marcos-password-hash` **and** `wifi-psk`. Keep it intact: removing entries without authorized SOPS editing invalidates its MAC. Only `wifi-psk` is now selected from this file; the password comes from the separate shared source. `wifi-psk` supplies native root-owned runtime NetworkManager profiles through a private environment adapter. The old file-secret agent and Noctalia patch are not imported. SenecaNET identity/password use a separate encrypted file, filled privately by the operator and now selected after successful MAC/decryption and marker/format checks; see [Wi-Fi procedure](../.agents/skills/desktop/references/desktop.md#wi-fi-credentials). This does not prove the campus account/password or server-certificate policy works on the real network. Do not delete/edit ciphertext fields by hand.

`.sops.yaml` preserves the previous exact ThinkPad rule and has separate exact rules for `secrets/hosts/thinkpad-senecanet.yaml` and the prepared `secrets/hosts/thinkpad-tailscale.yaml`, using the **same operator + dedicated ThinkPad public recipients**. The operator has now supplied the enrollment file via `sops edit`; ThinkPad's unactivated candidate selects it. These host-specific rules/ciphertexts have no recipient expansion, new identity or key rotation. The explicitly authorized shared-password rule below is separate; there is no catch-all. Initial creation encrypted only public replacement markers without decrypting the existing password/PSK file. The later **2026-09-10 operator-run private audit** verified both filled ciphertext files in memory; neither ciphertext was modified by that audit or this commissioning change. See [partial preflight evidence](../.agents/skills/fleet-operations/references/hosts.md#partial-commissioning-preflight-2026-09-10-utc).

## Retire server recipients — operator-run, pending

**2026-09-13:** the operator chose to perform ciphertext rotation privately, not authorize agent access to the recovery identity. No ciphertext, `.sops.yaml` recipient rule, secret value or private identity was changed by this follow-up. The existing Nix recipient list remains an honest oracle for current ciphertext, not evidence of completed revocation. Configuration removal and omitted reinstall staging do not erase keys already present in old `/persist`, backups or generations.

Use the locked Linux shell, independently verified operator recovery identity (owned `0600`, private parent, outside checkout/store) and an off-repository recovery copy. Retain access to recovery archives: do not delete old server identities merely because the new OS no longer needs them. Before the following native SOPS operations, edit **only the public policy**:

- In `.sops.yaml`, retain `operator` and `thinkpad` key aliases. Remove `racknerd`, `racknerd-previous` and `bastion` aliases. Set the shared-password rule to operator + ThinkPad, the retained Racknerd archive rule to **operator only**, and remove the unused Racknerd Tailscale creation rule. Keep all three ThinkPad host-file rules unchanged; there is no catch-all.
- In `modules/access/administrators.nix`, remove only the Racknerd and Bastion age strings from `recipients`, retaining operator + ThinkPad. Do not modify administrator/deployment SSH keys.

Do not evaluate, stage or commit the intermediate policy/ciphertext mismatch. SOPS **3.13.3** supports simultaneous removal and data-key rotation; run these commands in your private operator terminal, not an agent/logged session:

```sh
(
  set +x
  set -euo pipefail
  umask 077
  : "${SOPS_AGE_KEY_FILE:?Set the reviewed private operator age identity path}"
  export SOPS_AGE_KEY_FILE
  sops rotate --in-place --rm-age \
    'age1n9krs7x7qrsw9zcz6mvumc9zyr5f7axhlvdf0fnnflzxsh3kkqmqp5rgdd,age1su25ytldd4uye705w6jllwzkmpdkprruq5mzpcrth0e9zcmcyewspeck6q' \
    secrets/shared/marcos-password.yaml
  sops rotate --in-place --rm-age \
    'age1dpxn0ymj6jyt33yf9ukuekwh93w8r3gsmfx8d3g3g3vhh5dn7ygsdpy48t' \
    secrets/hosts/racknerd.yaml
  bash scripts/secrets/check.sh
)
```

These operations preserve secret values, verify existing MACs and re-encrypt with fresh data keys after removing the server recipients; they are not password rotation. Do not use `--ignore-mac`, hand-delete ciphertext envelopes, or substitute recipient-only `updatekeys` without data-key rotation. If either operation fails, stop and finish/recover the coherent pair before any staging/evaluation. Review that only the two intended ciphertext files and two public-policy files changed, with no plaintext/private files; the guard must pass before staging and a separate commit. Full validation/builds remain required once testing is authorized.

**Historical access cannot be revoked:** old Git/store/backups may still contain ciphertext decryptable by old server keys. The retained password/hash is consequently still recoverable from those old copies. Actual password/API-key rotation is a distinct operation, not performed or authorized here. Fresh data keys prevent old recipients from decrypting future changed values in these new ciphertext lineages; keep future rules server-free until a real service justifies new scoped credentials.

## Shared marcos password

**2026-09-11:** the user selected the existing ThinkPad password for all three accounts and explicitly authorized local in-memory extraction/re-encryption. The existing operator recovery identity matched its reviewed public recipient; its owned `0600` file and `0700` parent were checked. Native SOPS extracted only the password field into the password-only shared YAML, verified the original/new MACs and compared the hashes in memory. No password/hash/private identity entered tool output, arguments, plaintext files, Git or Nix inputs. No identity was generated or exported.

The original shared rule granted only **operator, ThinkPad and Racknerd** access; the authorized 2026-09-12 update below adds Bastion only to this file. Original host ciphertext and all Wi-Fi/campus/enrollment recipient rules remain unchanged. Do not edit the retained original password entries for future account-password changes: the selected source is `shared/marcos-password.yaml`. Sharing a password deliberately shares its compromise/rotation scope; key-only SSH, password-required sudo and distinct host identities remain unchanged.

At that checkpoint Bastion was deliberately blocked. **2026-09-12 supersedes that decision:** following verified live-USB access and explicit key-generation authorization, its distinct recipient `age1su25ytldd4uye705w6jllwzkmpdkprruq5mzpcrth0e9zcmcyewspeck6q` is now in `fleet.secrets.ageRecipient`, the public `recipients` policy in `modules/access/administrators.nix`, the exact shared rule and ciphertext. Native `sops updatekeys` preserved the encrypted password payload; operator and isolated Bastion identities both passed MAC-checked decryption and in-memory equality with the original value. Every host-specific ciphertext file remained byte-identical.

The actual pinned users manifest/helper was rehearsed in the authenticated live USB under separate authorization: the age key was temporarily root `0600` under its direct `/persist` runtime path, the early password was root `0400` in native RAMFS, equality passed, account-file metadata was unchanged, and temporary secrets/key/mount were removed. This is genuine **pre-install identity review**, not a claim about the eventual boot. Private identities/signing key have an off-Bastion encrypted recovery archive with in-memory restore/byte comparison; keep independent custody before the eventual ThinkPad wipe. Only public closure trust goes into Bastion's OS; the operator retains its private signer off-host.

`shared-password-recipients` checks YAML against the public Nix policy; full canonical checks remain mandatory. Missing/unlisted recipients still leave the account locked and block commissioning. No password value was rotated, no host-specific access was widened, and no installed password changed in this preparation. Racknerd was still blocked at that checkpoint; its separately authorized fresh identity/recovery/early-delivery review is recorded below. ThinkPad's fresh candidate remains unready. Actual installed delivery, login/sudo and reboot acceptance are recorded only in [current host status](../.agents/skills/fleet-operations/references/hosts.md#current-status).

## Racknerd fresh identity — 2026-09-12

The operator selected a complete fresh reset rather than restoring old Racknerd state. Distinct new SSH/age identities and a separate off-host signing key were generated under explicit authorization. The new age recipient is **`age1n9krs7x7qrsw9zcz6mvumc9zyr5f7axhlvdf0fnnflzxsh3kkqmqp5rgdd`**. Protected off-Racknerd encrypted recovery was decrypted and byte-compared in memory; the operator retains the decrypting identity and private signer outside Racknerd. Keep independent recovery before any later ThinkPad erasure.

Only Racknerd's recipient in the selected shared-password ciphertext/policy was replaced. The encrypted password payload and MAC, and every host-specific ciphertext file, remained unchanged; operator and isolated new Racknerd identity both passed MAC-checked decryption/equality. The exact historical `hosts/racknerd.yaml` rule now names **`racknerd-previous`**, retaining its original recipients without giving the new host unnecessary access to that unselected credential. The not-yet-supplied Racknerd enrollment rule uses the new identity. This is not password rotation or revocation of historical shared-password knowledge.

The exact native users manifest/helper ran in the console-verified live installer with the new temporary root-only key. Native RAMFS delivery was root `0400`, equality passed without printing values, account-file metadata was unchanged, and all temporary key/secret/mount state was removed. This justifies pre-install `identityReviewed`; actual installed delivery, password sudo and reboot persistence remain separate in [current status](../.agents/skills/fleet-operations/references/hosts.md#current-status). No old filesystem was mounted or old private identity read.

## Racknerd provisioning checkpoint

**2026-09-10 evidence; [current status](../.agents/skills/fleet-operations/references/hosts.md#current-status) governs remaining acceptance.**

The [authorized access bootstrap](../.agents/skills/fleet-operations/references/hosts.md#authorized-access-bootstrap-and-sops-preparation) now provides working marcos key login and operator-tested password sudo while retaining root SSH and the old generation. Racknerd's newly generated dedicated identity has the verified public recipient recorded as `&racknerd` in `.sops.yaml`. Its exact `hosts/racknerd.yaml` and `hosts/racknerd-tailscale.yaml` rules include only that recipient and the existing operator. ThinkPad recipients/ciphertext remain unchanged.

The operator supplied the existing marcos password hash as encrypted `marcos-password-hash` via regular `sops edit`; `just secret-check` validated the ciphertext/recipients without decryption, and that checkpoint's unactivated candidate selected it as the early root-only credential. The shared-password policy above now supersedes that source selection. No account hash, private identity or real credential was returned to the agent. The encrypted recovery copy is operator-saved but its recovery test was declined; `identityReviewed` remains false until early decryption and recovery are verified. Racknerd's commissioning review status is recorded in [the host inventory](../.agents/skills/fleet-operations/references/hosts.md#commissioning-review-status-2026-09-10). The separate exact `tag:fleet-racknerd` enrollment key (`tailscale-auth-key`) is still to be provisioned near its own rollout; never reuse ThinkPad's key or recipients.

## Runtime boundary

`fleet.access.passwordSecrets` maps known accounts to declared `sops.secrets` names. A null or undeclared name locks that candidate account and **blocks commissioning**, rather than pointing to a nonexistent manual hash file. The candidate must not be activated in that state; installed passwords are untouched.

Declare password hashes with `neededForUsers = true`. Account `hashedPasswordFile` values come from the secret's `.path`, normally `/run/secrets-for-users/NAME`, root-only mode `0400`, in SOPS' default ramfs. Password values/hashes are never evaluated by Nix. The ordinary activation-script account backend installs these secrets before creating immutable users. ThinkPad's interactive account retains password/fingerprint sudo. The dedicated deploy account on all hosts instead has narrowly described NOPASSWD activation/confirmation commands plus explicitly approved root-equivalent Nix trust; root SSH remains disabled. See the [deployment policy and transition](../.agents/skills/deploy/SKILL.md).

Only hosts with selected SOPS secrets require a private age identity and genuine identity review; a future service secret reintroduces those blockers rather than silently provisioning an identity. Secret-free hosts must leave the age path/recipient null and active review metadata absent. Where required, the private age identity is a **runtime string path**, directly on early-mounted `/persist`. Parent must be root-owned `0700`, key root-owned `0600` (or stricter), with protected recovery copies outside Git. Do not bind `/var/lib/sops-nix` merely to reach it, persist `/run/secrets*`, auto-generate keys or import SSH identities implicitly. Disk persistence is not encryption: review physical access/backups on each host.

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

After **both** markers have been replaced and the file reviewed, select it inside the existing `fleet.hosts.thinkpad.module` body in `modules/desktop/wifi.nix` (already done for the audited ThinkPad file):

```nix
fleet.wifi.senecaSopsFile = ../../secrets/hosts/thinkpad-senecanet.yaml;
```

Until then, leave the option's default **`null`**: no campus profile is emitted and commissioning remains blocked. The runtime adapter also rejects either marker in any credential field if the file is selected prematurely; the shared environment/profile preparation then fails, including MN-Home delivery. Do not select an unfilled file just to remove the null blocker. Run [manual ciphertext guard](../.agents/skills/validate/references/ciphertext.md) before staging and [full manual validation](../.agents/skills/validate/SKILL.md) after the reviewed change.

The actual Wi-Fi manifest and separate `senecanet-template-manifest` checks validate encrypted key selection only. The latter can pass against **markers** and is never proof of valid credentials, decryption or readiness.

Never disable Seneca's CA/domain validation to compensate for missing credentials. Back up/reconcile duplicate old profiles deliberately before activation, then test password delivery and server-certificate rejection on the real network under separate authorization.

## Tailscale enrollment

See [current credential/rollout status](../.agents/skills/fleet-operations/references/hosts.md#current-status) and [private provisioning](../.agents/skills/tailscale/references/tailscale.md#thinkpad-auth-key-preparation). Use ordinary private `sops edit`; exact per-host recipient rules and structural checks are required before staging. Each enabled host will need either a verified existing node identity (`preserve`) or its own reviewed short-lived, single-use, non-ephemeral, exact-tag auth key delivered by a declared SOPS secret (`auth-key`). Host tags are not unique constraints: never issue another device ThinkPad's privileged tag. Do not install tailnet-administration OAuth credentials on a host.

Use ordinary `/run/secrets/NAME`, root-only `0400`, `neededForUsers = false`, and `restartUnits = [ "fleet-tailscale.service" ]`. Select the secret by name in `fleet.tailscale.authKeySecret`; arbitrary runtime/store key paths are not accepted. The owning unit passes only a file reference to the CLI. Preserve daemon identity in the reviewed root-only `/persist/var/lib/tailscale` backing. A consumed key need not remain delivered once durable identity has been verified and the host is switched to `preserve`; never hand-edit encrypted payloads/MACs.

Tailnet API credentials and the OpenTofu recovery passphrase are separate operator-runtime secrets, not NixOS/SOPS host inputs. Keep normal local state/plans/provider working data outside Git/Nix store with enforced encryption and independent recovery; preserve OpenTofu's [emergency-state exception](../.agents/skills/tailscale/references/tailscale.md#emergency-state-recovery) after backend write failure. The operator-supplied public tailnet ID is recorded in `tofu/tailscale/tailnet.json`; this is not a secret or proof of API access. [Dated status/evidence](../.agents/skills/fleet-operations/references/hosts.md#current-status) distinguishes completed operator-reported policy maintenance from host-state backup, credential delivery and enrollment acceptance. The [policy-only procedure](../.agents/skills/tailscale/references/tailscale.md#policy-only-apply-workflow) documents the required posture-write dependency and retains DNS read-only. Keep the read-only client unchanged and the same state passphrase; use those read-only credentials privately for non-saving `tailnet verify` inside native devenv. No credential values are needed by the agent. The synthetic fixture's encrypted Wi-Fi key selection is **not** a Tailscale credential or enrollment test.

## Runtime operator SOPS delivery

[Native devenv's SOPS → OpenTofu adapter](../.agents/skills/devenv/references/development.md#sops--opentofu) loads only the three operator credentials into the guarded child process. It does not change host SOPS delivery, create identities/ciphertext, widen recipients, replace the existing state passphrase or authorize API operations. No SecretSpec evaluation-time loading or automatic shell/task decryption is enabled.

## Safe operator workflow

The native devenv shell supplies `sops`, `age` and `yq` for reviewed maintenance. Shell entry, [manual ciphertext guard](../.agents/skills/validate/references/ciphertext.md) and [full manual validation](../.agents/skills/validate/SKILL.md) do not decrypt anything or contact targets.

1. Recover/verify existing identities and the intended password-sharing scope under **separate authorization**. Do not print/export hashes or keys through agent tools, command arguments, shell history or logs. Do not copy ThinkPad ciphertext to other hosts or widen its recipients as a shortcut.
2. If a host needs an identity, provision a distinct one and verify its public recipient through a trusted channel, with recovery custody established. No generation or provisioning is automatic. Add only reviewed exact file rules, operator recovery access and verified host recipients. Shared-password membership additionally requires the matching Nix recipient policy; do not widen unrelated host files.
3. In a secure interactive SOPS editor, preserve the intended existing password hash or explicitly approve a new password; use protected temporary storage and no plaintext editor swap/backup files. Do not expose a hash to the agent. Any separately authorized automated transfer must keep plaintext entirely in subprocess memory/pipes, with no plaintext files, arguments, logs or private-key export; routine checks never decrypt. Never use `builtins.readFile` on a runtime secret, `hashedPassword` with a real hash, or private-key path literals as Nix inputs.
4. Add the encrypted host source and `sops.secrets.NAME` declaration to a top-level module under `modules/`; select it in `fleet.access.passwordSecrets.USER` and set the verified `fleet.secrets.ageKeyFile` string and public `fleet.secrets.ageRecipient`. Current shared-password declarations are centralized in `modules/access/administrators.nix`. No dependency on the old repository remains.
5. **Before staging**, run [manual ciphertext guard](../.agents/skills/validate/references/ciphertext.md) and inspect the diff securely; stage only intended ciphertext/public rules/code. The structural check rejects ambiguous YAML (multiple documents, duplicate keys or merge keys), accidental plaintext payloads and recipient-rule drift; it also rejects extra keys in the password-only shared file. It does not prove a valid MAC/hash, matching private identity or working login. [Manual ciphertext regressions](../.agents/skills/validate/references/ciphertext.md#regressions) exercise malformed copies in a temporary local directory without touching host state. Nix's both-track manifest builds check selected keys without decrypting. Never add a Git textconv that reveals secrets during agent diff review.
6. With independent console/recovery access and separate host-operation authorization, verify identity permissions/custody, recovery and real early decryption before acknowledging `fleet.secrets.identityReviewed`. Existing-installation adoption also needs staged non-root access/password sudo before activation. For an explicitly authorized fresh install from a verified live USB, rehearse the exact native early-users helper with protected runtime-only staging before erasing the OS disk; this does not claim that the new persistent mounts, account/PAM stack or boot have been accepted. Actual installed delivery, non-root login/password sudo and reboot persistence remain mandatory subsequent acceptance. Never turn a structural manifest check into a decryption/recovery acknowledgement.

The historical [ThinkPad private-audit record](../.agents/skills/fleet-operations/references/hosts.md#partial-commissioning-preflight-2026-09-10-utc) returned only metadata/booleans, not passwords, hashes or identities. Its then-pending boot/delivery checks were subsequently completed as recorded in [current status](../.agents/skills/fleet-operations/references/hosts.md#current-status); campus authentication and later Tailscale delivery remain separate acceptance items. Never obtain key material merely to record a review confirmation.
