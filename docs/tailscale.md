# Tailscale: staged clients and declarative tailnet

See [ADR 0009](adr/0009-tailscale-and-opentofu.md) and [dated API evidence](research.md#staged-tailscale--opentofu--2026-09-10).

## Current status — 2026-09-10

**Policy maintenance complete (operator-reported); clients not enrolled.** The operator confirmed a separate minimally scoped write client and a fresh, fully reviewed plan changing only `tailscale_acl.policy`, then reported **Apply complete: 0 added, 1 changed, 0 destroyed** under the explicit policy-only authorization. DNS was excluded from the reviewed change. The operator subsequently reported **No changes** from verification and confirmed post-apply independent recovery access and checked protected backups. These completed policy checks are not client enrollment or traffic acceptance. See the [apply evidence record](validation.md#operator-reported-policy-apply-and-non-saving-verification--2026-09-10).

Before application, the operator confirmed the intended tailnet, scopes, exclusive writer control, unused/uniquely correct fleet tags, independent administrative access and tested offline policy/DNS/state-backup recovery. The prior plan remains at `$TAILSCALE_STATE_DIR/reviewed-plan-71i6d10m/change.tfplan`; the freshly applied plan is retained at `$TAILSCALE_STATE_DIR/change.tfplan`. After the apply report, the agent checked only tailnet binding, ownership/permissions (`0700` directory, `0600` state/plan files) and encrypted envelopes, without decryption, mutations or API access. Preserve these files and use the [non-saving verification workflow](#post-apply-verification), not another apply.

The public tailnet ID **`Td9HdopnWQ11CNTRL`** is recorded in [`tofu/tailscale/tailnet.json`](../tofu/tailscale/tailnet.json). Both OpenTofu and the wrapper read this single source; optional environment confirmation cannot retarget it. **ThinkPad's candidate now enables auth-key enrollment; it has not been activated.** Its supplied SOPS key and operator-reviewed retained state, policy/tag intent and protected host-state backup are selected. The candidate adds the daemon/enrollment unit, UDP 41641 and the existing backing-state bind. Racknerd, Bastion and Dino remain disabled with their review blockers intact; OS commissioning flags are unchanged. `just tailscale-inventory` reports separate rollout prerequisites; `just inventory` still reports OS commissioning.

The earlier authorized read-only SSH inventory used previously verified host keys, strict checking and no key updates/forwarding. During that inventory, no deployment, reboot, state read/copy/reset, secret decryption or tailnet API operation occurred:

| Host | Observation | Remaining requirement |
|---|---|---|
| thinkpad | No Tailscale service/CLI in the running system; state-path metadata unavailable with available privileges | Privately determine whether retained backing identity exists; don't infer absence |
| racknerd / bastion / dino | Old configurations, active daemon, `NeedsLogin`, no current tailnet/node ID. Live and backing directories `0700 root:root`, state files `0600 root:root` | Review retained state and its binding/backups before choosing enrollment; metadata does not prove state-file contents or identity equivalence |

`just ready racknerd`, `just ready bastion`, and `just ready dino` all refuse deployment. Servers still need the safe non-root access/SOPS/trust transition; Dino also needs its original stateVersion/EFI/boot-filesystem review; Bastion needs its NAS import/restore review. **Do not deploy the new baseline first to discover these facts.** Follow [host commissioning](hosts.md#access-and-state-migration-checklist--no-execution-authorized) with independent recovery. A successful evaluation cannot authorize or substitute for those transitions.

## Access policy

`tofu/tailscale/policy.hujson` is JSON (a valid HuJSON subset). Tailscale's recommended **grants** implement network ACLs:

| Initiator | Destination | Allowed |
|---|---|---|
| `tag:fleet-thinkpad` | `tag:fleet-racknerd`, `tag:fleet-bastion`, `tag:fleet-dino` | TCP 22 and ICMP |
| Everything else | Everything else | No grant: denied |

Replies to allowed connections are stateful; the reverse initiation is not allowed. This is ordinary OpenSSH with the existing account/key/sudo policy, **not Tailscale SSH**. There is no member-wide rule, `autogroup:self` exception, family-device access, subnet/exit-node approval, Funnel or application grant. Native policy tests include TCP/UDP distinction, ICMP and reverse/lateral denials.

This replaces the **entire existing tailnet policy**, not just the fleet's section. Thus existing personal/family-to-personal/family access is also removed unless separately reviewed and explicitly added. Back up/export and review the existing policy privately before applying. Neither the policy nor tests invent family account/device identifiers. Future pairs need actual identities, direction, protocol/ports and new positive/negative tests.

A tag is an identity/role, **not a hardware fingerprint or unique constraint**. Only administrators own these tags. Assign each fleet tag to exactly one intended device; never give another device ThinkPad's tag or a key capable of requesting it. Verify tag cardinality in the admin console before applying/enrolling and after replacements; revoke obsolete nodes before reusing a tag. Family members should have ordinary member roles, not policy/tag administration rights. Tagged nodes replace user ownership, which affects user-based features and default device-key expiry; review that trade-off/expiry deliberately.

The ACL protects **Tailscale traffic only**. Existing public/LAN SSH and other non-tailnet firewall policy remain unchanged for recovery. MagicDNS/control-plane traffic is not a peer-service grant. Test with ordinary `ping` or `tailscale ping --icmp`: default `tailscale ping` uses TSMP and is not proof of ICMP ACL permission.

## OpenTofu ownership and private local state

The locked development shell supplies stable OpenTofu **1.11.8** with only Nix-pinned Tailscale provider **0.29.0**, offline. `.terraform.lock.hcl` records that packaged linux_amd64 artifact. Init reports the locally mirrored provider as **unauthenticated** because it is not an upstream signed release archive: trust comes from the pinned Nix source/build/cache verification. Do not silently replace it with a registry binary or regenerate its checksum on unexplained mismatch. New platforms and provider updates need explicit review/tests. There are no new flake inputs or host package-track changes.

OpenTofu owns:

- The complete policy through `tailscale_acl.policy`, with import protection and no reset-to-default on destruction; `prevent_destroy` adds an explicit guard. Removing the resource block also removes that lifecycle guard, so deletion always needs review.
- MagicDNS through `tailscale_dns_preferences.tailnet` (`magic_dns = true`). **Review this tailnet-wide change**, including personal/family DNS behavior, before the first apply. Global/split resolvers and search domains are not managed or overwritten.

It deliberately does **not** create auth keys, OAuth clients, family accounts/devices, subnet routes, or an assumed tailnet. Bootstrap secrets remain separately provisioned. Provider v0.29.0's known auth-key recreation issue is outside the resource set used here.

### Operator setup (private terminal only)

This is the repeatable operator procedure; initial read-only completion is recorded above. These commands are never run by checks, and this procedure is not authorization to apply. Preserve the existing state directory/passphrase and do not repeat successful imports merely to restore a shell environment.

1. Independently confirm that the recorded tailnet ID names the intended tailnet, verify administrator recovery and export/review its existing policy and DNS settings. Disable any prior GitOps publisher/other OpenTofu state managing the policy. Prefer the admin console's **Prevent edits** setting plus a repository reference; it permits emergency overrides, which must be reconciled into Git before the next apply. Provider updates replace the whole document without optimistic concurrency. Local locking protects only this state, not another writer.
2. For the first **read-only preflight**, create an OAuth client in the intended tailnet's admin console: **Trust credentials → Credential → OAuth**. Select only the following **Read** permissions, including the policy scope's required dependencies ([official scopes](https://tailscale.com/docs/reference/trust-credentials#scopes), reviewed 2026-09-10):

   | Scope | Purpose |
   |---|---|
   | `policy_file:read` | Read/validate the policy |
   | `dns:read` | Read DNS preferences/settings |
   | `devices:core:read` | Required by policy read |
   | `devices:posture_attributes:read` | Required by policy read |

   Do not select Write, `all`, `all:read`, auth-key creation or device-management permissions. These read scopes do not require enrollment tags; do not edit live tag ownership to create this client. If the UI requires unrelated privileges, stop and review rather than broadening access. Store its client ID and one-time-displayed secret in your trusted password manager ([OAuth setup](https://tailscale.com/docs/features/oauth-clients#setting-up-an-oauth-client)). Supply them only through the runtime environment below. This client cannot apply changes; a future apply requires separately reviewed write credentials and authorization, not an automatic permission escalation after an error. Do not use enrollment keys as API credentials, put secrets in `.tfvars`, enable TF debug logging or paste them into an agent conversation. See [secret handling](../secrets/README.md#safe-operator-workflow).
3. Generate a separate random single-line passphrase in your trusted password manager (at least **32 characters**; 48 or more recommended). Keep an independent protected recovery copy and verify you can retrieve it without this machine or the tailnet. Do not generate/show the real passphrase through agent tools. Keep encrypted state/backups and the recovery key independently recoverable. A path/key prompt is not proof of tested recovery. State and saved plans use enforced PBKDF2/AES-GCM with **no plaintext fallback**; the passphrase is an ephemeral variable. Backend working metadata is not secret storage. Encryption does not hide values from an authorized CLI operator or protect against lost/corrupted/stale state.
4. From the repository root in a **private terminal**, first enter a clean locked shell. This avoids inherited API-key/OIDC credentials, alternate API endpoints, debug settings and shell startup integrations; never launch an agent/editor from the later credential-bearing shell:

   ```sh
   nix develop --no-update-lock-file --ignore-environment --keep HOME --keep TERM \
     -c bash --noprofile --norc
   ```

   Paste this **whole brace block** into that shell before entering values at its hidden prompts. Braces retain exports in the current shell and group the pasted commands before reads begin. Never paste values as shell commands or into chat:

   ```sh
   {
     set +x
     set +o history
     umask 077
     trap 'unset TAILSCALE_OAUTH_CLIENT_ID TAILSCALE_OAUTH_CLIENT_SECRET TF_VAR_state_passphrase' EXIT
     # The public tailnet ID is read from the checked-in tailnet.json.
     # Use the same reviewed persistent location on every invocation.
     export TAILSCALE_STATE_DIR="$HOME/.local/state/infra-tailnet"
     for variable in TF_VAR_state_passphrase TAILSCALE_OAUTH_CLIENT_ID TAILSCALE_OAUTH_CLIENT_SECRET; do
       IFS= read -r -s -p "$variable: " "${variable?}" </dev/tty || exit 1
       printf '\n'
       export "${variable?}"
     done
     unset variable
   }
   ```

   For **first initialization only**, then run `just tailnet init` separately. If already initialized, restoring the exports does not require reinitialization or a new passphrase. Stay in this private shell for the following operations: a fresh clean shell clears these inputs. A missing-variable error stops before API access; it is not an instruction to create replacement state.

   The wrapper binds a new empty private `0700` directory to that tailnet. State, backups, saved plans and provider working data stay **outside the checkout/Nix store**. Existing nonempty/unbound directories require recovery review; permissions are never silently repaired. No auto-loaded `.tfvars` or override files, alternative workspaces, TF_CLI_ARGS overrides, debug logging or TF_ENCRYPTION overrides are accepted. The environment is transient: unset credentials/passphrase after use. State and plan output may disclose network metadata, so review privately.
5. **After authorizing read-only API access**, import both existing singletons into encrypted local state:

   ```sh
   just tailnet import-policy &&
   just tailnet import-dns &&
   just tailnet plan
   ```

   Imports change local state, not the live tailnet. A plan contacts the API but does not apply. Review the complete policy/DNS diff and policy tests, verify one intended node per privileged tag, preserve out-of-band access, and authorize the exact change separately. A saved plan remains at `$TAILSCALE_STATE_DIR/change.tfplan`; no older plan is silently overwritten. Expect only updates or no-ops for `tailscale_acl.policy` and `tailscale_dns_preferences.tailnet`; stop for creates, destroys or unrelated addresses. Provider/server validation on apply is still required; offline mocks are not Tailscale's policy engine. At the end of this preflight, **stop without applying and `exit` this private shell** to drop its credential environment. Exporting variables here does not update an already-running agent session. Report only which steps succeeded, the add/change/destroy counts and sanitized blockers; keep raw policy, state, plan, token responses and credential-bearing diagnostics private.
6. **Only after explicit authorization**, `just tailnet apply` applies that saved plan after an exact tailnet-ID confirmation. It changes the live tailnet, not NixOS. The plan is retained; archive it securely outside Git before making the next plan. Do not reuse old plans after policy/emergency changes; replan against refreshed state and serialize all applies. Never wire apply into `just check`, shell entry, a Nix build or NixOS activation.

Raw OpenTofu can bypass the wrapper's workflow guards. Keep the checked configuration and use the wrapper for real operations; do not remove encryption/import protections to recover from an error. Local state is not a remote/team backend: use one administration environment, maintain backups and deliberately migrate if additional operators/CI need access.

## Policy-only apply workflow

**Steps 1–4 below record the completed application sequence, not authorization to repeat it.** Continue with [post-apply verification](#post-apply-verification).

This procedure is scoped to the reviewed whole-policy replacement for `Td9HdopnWQ11CNTRL`, with **no DNS changes**. The current task's authorization does not cover later/unreviewed changes, enrollment, host activation/reboot or OS/NAS storage operations. Keep competing writers paused throughout refresh, review and application; any intervening policy change invalidates the review.

1. In **Trust credentials → Credential → OAuth**, privately create a **separate** client; keep the existing read-only client unchanged. Select exactly these permissions ([official scope dependencies](https://tailscale.com/docs/reference/trust-credentials#scopes), reviewed 2026-09-10):

   | Scope | Console permission | Why |
   |---|---|---|
   | `policy_file` | Write | Publish the reviewed policy |
   | `devices:posture_attributes` | Write | Required dependency of policy write |
   | `devices:core:read` | Read | Required dependency of policy write |
   | `dns:read` | Read | Refresh unchanged DNS preferences |

   **Posture Write is an actual additional capability required by Tailscale**, not permission to modify posture in this task; the repository does not manage those attributes. Do not select DNS Write, device-core Write, auth keys, routes, `all` or `all:read`; no enrollment tags are needed. If the console demands unrelated grants, stop rather than expanding privileges. Keep the new ID/secret in protected storage and never pass them through chat, Git, Nix inputs or command arguments. The operator has confirmed this client's scopes for the recorded application; future use requires a fresh review.
2. In a clean private shell, use the **same brace-block prompts from operator setup** with the existing recovery passphrase and the **new client's** ID/secret. Restore the existing state-directory export; **do not initialize, reimport or generate a new passphrase**. The old plan was already archived for this task; do not move it back or archive anything else automatically.
3. Generate the requested fresh plan:

   ```sh
   just tailnet plan
   ```

   Stop and privately review the complete diff. It must still propose **0 additions, 1 update, 0 deletions**, changing only `tailscale_acl.policy` to the previously reviewed contents. Report only those counts, the resource address and whether the full diff matches. Any DNS change, different resource, create/destroy, policy-content difference or error is outside this approval: stop and review, without widening scopes or disabling tests/guards. Never chain a successful plan directly into apply. The recorded application used a fresh plan whose full contents and minimal client scopes were explicitly operator-confirmed.
4. **Only after that fresh-plan review is satisfied**, the explicitly authorized policy-only operation is run separately in the private terminal:

   ```sh
   just tailnet apply
   ```

   The wrapper prompts for the exact tailnet ID. Enter `Td9HdopnWQ11CNTRL` interactively only after verifying the plan and continued recovery/writer control. Server errors or failed policy tests must be investigated, not bypassed. Keep raw output private and report only sanitized success/failure and resource counts. A failed/partial apply requires fresh state/plan review, not blind reuse of this artifact. The operator reports the authorized application succeeded; do not run it again for verification.
5. After success, follow [post-apply verification](#post-apply-verification), update protected backups, and review retirement of the maintenance-only write client. Exit the private shell when finished. Success does not establish live client enrollment or allowed/denied traffic tests, and does not authorize any host operation.

## Post-apply verification

In the clean private shell, restore the existing state-directory/passphrase and the **original read-only client's** ID/secret using the operator-setup brace block. Do not create another client, reinitialize, reimport, rerun apply or move/overwrite either saved plan. Then run:

```sh
just tailnet verify
```

`verify` reuses all wrapper guards and runs a normal refreshing `tofu plan -input=false -lock-timeout=60s -detailed-exitcode`, **without `-out`**. It reads the managed live policy and MagicDNS preference but does not apply changes or create/replace a saved plan. The detailed result is **0 = no changes**, **2 = differences proposed**, **1 = error**; `just` reports a failed recipe for either nonzero result. A guard/input failure also remains a failure. Do not convert differences/errors into a passing check, use `-refresh=false`/targeting, or apply a proposed correction without reviewing it and obtaining new authorization.

Expect **No changes**. Report only that result (or sanitized differences/errors), and separately confirm the intended live policy/MagicDNS plus administrative and out-of-band recovery access still work after the update. Keep raw plans, policy contents and credentials private. Verification covers only managed configuration, not real allowed/denied traffic, tag cardinality over time, node identity durability or hardware boot. Update protected state backups after success and retain the applied plan until deliberate archival; exit the private shell to drop its credential environment. For this maintenance task, the operator has reported **No changes** and confirmed post-update administrative/out-of-band access plus updated, checked protected backups. Do not repeat completed checks just to update status documentation.

## ThinkPad auth-key preparation

The operator reports deleting the nodes in the control plane. ThinkPad's retained profile is therefore **not proof of a reusable login**, even though its saved `LoggedOut` is false. Its live state path is absent; the backing directory/file were operator-confirmed as root-owned `0700`/`0600`. The private projection showed one selected profile with an old non-fleet tag, shields-up enabled, and no saved routing, Serve, SSH, operator or remote-management features. Preserve that backing file; do not erase it or restore a deleted control-plane identity. The operator has now confirmed a protected, recoverable host-state backup, separately from OpenTofu backups.

The exact rule for `secrets/hosts/thinkpad-tailscale.yaml` uses the **existing operator and dedicated ThinkPad public recipients**. The operator supplied this ciphertext using `sops edit`; its encrypted auth-key field and exact recipients passed structural checks. ThinkPad's candidate selects it as the root-only runtime secret and enables `auth-key` mode. Decryption/delivery and real enrollment are not proven by those checks. The following is the simple provisioning procedure, not an instruction to regenerate the completed key:

1. In the intended tailnet **`Td9HdopnWQ11CNTRL`**, create an **auth key**, not an OAuth client/API key: short-lived, **Reusable off**, **Ephemeral off**, and only **`tag:fleet-thinkpad`** (not the old tag). Leave **Preauthorized off** if offered and approve the device after first contact if required; do not broaden permissions or turn off tailnet approval to speed up enrollment. The key is for this ThinkPad only. Keep its value out of chat and do not run `tailscale up` manually.
2. In a private terminal and development shell, use a trusted local editor with swap/backups and AI/cloud integrations disabled. Put the real key in the `tailscale-auth-key` YAML field; let SOPS manage encryption/MACs. No OAuth credential or OpenTofu passphrase is needed:

   ```sh
   sops edit secrets/hosts/thinkpad-tailscale.yaml
   ```

3. Run `just secret-check` before staging anything and report only success/failure, confirmation of the exact key settings above, and whether the retained **host-state** backup is protected and recoverable. Exit the private shell. Do not paste the key or raw diagnostics, overwrite a failed/existing file automatically, or repeat node deletion.

Those preparation prerequisites are now operator-confirmed and selected for ThinkPad only. Run canonical checks/readiness/build **once for the substantive candidate change**, review the complete candidate (including the unactivated desktop fix), then obtain activation authorization. If the daemon does not report `NeedsLogin`, the reconciler will not submit the key or force a reset; stop and review instead of bypassing that guard. No other host rollout is implied.

## Per-host rollout

1. Review existing node identity, private backing state and live/bind equivalence without printing state contents. Back up/migrate only under separate authorization; never copy one device's state to another. A `NeedsLogin` daemon is not authorization to erase its old state. Persist `/var/lib/tailscale` at `/persist/var/lib/tailscale`, root-owned `0700`, with private state files; verify existing backing permissions because impermanence does not repair them automatically. The daemon requires both mount paths before starting. Do not create/import NAS datasets or alter existing OS mounts.
2. For new authentication, privately generate a separate **short-lived, single-use, non-ephemeral auth key**, scoped to exactly that host's tag. Use preauthorization only for the already verified device, or approve the pending device manually. Never install reusable tailnet-administration OAuth credentials on a host. Provision reviewed SOPS ciphertext with the verified operator and that host's distinct public recipient; no new keys/ciphertext/recipients are generated by this implementation.
3. Declare its SOPS secret in the existing host's top-level module contribution: root-only `0400`, ordinary runtime path `/run/secrets/NAME`, `neededForUsers = false`, and `restartUnits = [ "fleet-tailscale.service" ]`. Set `fleet.tailscale.authKeySecret` to that declaration's name and `enrollmentMode = "auth-key"`. The ciphertext source/key selection must be real. `just secret-check` precedes staging. ThinkPad's existing Wi-Fi/password ciphertext is not a Tailscale credential; the fixture's use of that ciphertext only tests shape/key selection.
4. For an already authenticated, correctly tagged node, select `enrollmentMode = "preserve"`, `authKeySecret = null`; do not reenroll it. Review any retained routing, Serve/Funnel or operator settings before reuse; this code does not silently reset old private state. Only after actual state/recovery and intended-tailnet/live-policy/tag review acknowledge `stateReviewed` and `policyReviewed`. Then change only that host's entry in the `rollout` table in `modules/tailscale/clients.nix` to true and deliberately update the real-host rollout oracle in `modules/validation.nix`. Do not set host `ready` or other review flags as a shortcut.
5. Run canonical checks and the affected commissioned host's readiness/build. Enabling a client adds UDP **41641** for encrypted tunnel transport, not a new application grant. It keeps native netfilter mode `on` (Tailscale manages its own overlay rules), never blanket-trusts the interface, disables Taildrop/Tailscale SSH/webclient/operator/auto-update and route/exit-node advertisement/acceptance, and accepts reviewed tailnet DNS. Host builds never publish tailnet policy. `services.tailscale.*` must not become a second enrollment/preferences writer.
6. With explicit host-operation authorization and verified recovery, activate one commissioned host at a time. The unit uses `--auth-key=file:...` **only in NeedsLogin**; it never force-reauthenticates, resets unknown preferences or submits a key to a pending-approval node. Running nodes retain identity; stopped nodes reconnect using a genuinely bare `up` bounded by external `timeout` (even `up --timeout` triggers the CLI's non-default-settings check). Exact self-tag and running-state checks reject unexpected identity results. Secret/CLI failures have sanitized diagnostics; inspect them privately rather than exposing credentials/login URLs. Network-online ordering and three bounded attempts cover transient startup failures; after exhaustion, correct the cause and explicitly reset/restart the unit, never disable guards.
7. Verify the **actual intended tailnet** in the admin console, unique correct tag, node identity/expiry and successful connection. Test allowed SSH/ICMP and denied reverse/lateral/family flows, unchanged out-of-band access, and stable identity across two authorized boots. A unit reporting success is not these acceptance tests. After successful durable enrollment, switch to `preserve` and remove the consumed runtime key binding/declaration in a reviewed follow-up; don't hand-edit ciphertext/MACs. Expired/revoked node credentials later require an explicit enrollment/recovery decision, not automatic key regeneration.

## Validation boundaries

`just check` covers both-track staged/enabled fixtures, own-track packages, persistence/mount requirements, review/secret/tag/override rejection, native CLI flag availability, offline mocked reconciliation/wrapper behavior, an exact initial-policy oracle with widening regressions, native OpenTofu schema/mock-provider plans and synthetic local encrypted-state/saved-plan tests including non-saving no-change/drift statuses, retained-file preservation and wrong-key/plaintext rejection. The encryption test's `terraform_data` apply writes only a temporary local fixture: **no cloud/tailnet provider, host activation, installer or daemon is run**.

These tests cannot establish real key validity/decryption, tailnet identity/plan entitlement, API policy acceptance, tag cardinality, firewall behavior, credentials, networking, hardware boot or restore. Read-only access/scopes, complete diff review and offline backup recovery are now operator-confirmed, separately from these tests. Exclusive policy-writer control, unused/uniquely correct fleet-tag assignments and independent administrative recovery access are now operator-confirmed for this maintenance task. The minimal write scopes and fresh exact policy-only diff were subsequently operator-confirmed, followed by a successful apply report. These attestations are not blanket authorization for later changes. The report is evidence of API acceptance, not an agent-observed readback or real allowed/denied flow test. The operator subsequently confirmed no-drift verification, post-apply independent recovery and checked protected backups. ThinkPad's host-state backup and key provisioning are now operator-confirmed; only its state/policy review flags and candidate rollout are enabled. Key validity, dedicated-identity runtime decryption, device approval and enrollment remain runtime gates. Other hosts' state/enrollment credentials and remote commissioning remain open; no OS commissioning flag changed. Deployment and live enrollment are not complete.
