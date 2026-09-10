# Tailscale: staged clients and declarative tailnet

See [ADR 0009](adr/0009-tailscale-and-opentofu.md) and [dated API evidence](research.md#staged-tailscale--opentofu--2026-09-10).

## Current status — 2026-09-10

**Imported and planned, not applied or enrolled.** The operator reports successful policy/DNS imports and a saved plan with **0 additions, 1 update, 0 deletions**, changing only `tailscale_acl.policy`; no DNS change is proposed. The operator confirmed the intended tailnet, the four read-only OAuth scopes, independent passphrase retrieval, complete diff review and offline recovery of protected original-policy/DNS and encrypted-state backups. The agent independently checked only ownership/permissions (`0700` directory, `0600` state/plan files) and encrypted-envelope structure, without decrypting files or inspecting the private plan. See the [evidence record](validation.md#operator-completed-read-only-tailnet-preflight--2026-09-10).

The public tailnet ID **`Td9HdopnWQ11CNTRL`** is recorded in [`tofu/tailscale/tailnet.json`](../tofu/tailscale/tailnet.json). Both OpenTofu and the wrapper read this single source; optional environment confirmation cannot retarget it. **Client rollout remains disabled** while host-specific prerequisites are unresolved. All four compositions include the capability, but `fleet.tailscale.enable = false`: no daemon, enrollment unit, new firewall port or persistence bind is added to a real host. Existing commissioning/review flags are unchanged. `just tailscale-inventory` reports separate rollout prerequisites; `just inventory` still reports OS commissioning.

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

## Per-host rollout

1. Review existing node identity, private backing state and live/bind equivalence without printing state contents. Back up/migrate only under separate authorization; never copy one device's state to another. A `NeedsLogin` daemon is not authorization to erase its old state. Persist `/var/lib/tailscale` at `/persist/var/lib/tailscale`, root-owned `0700`, with private state files; verify existing backing permissions because impermanence does not repair them automatically. The daemon requires both mount paths before starting. Do not create/import NAS datasets or alter existing OS mounts.
2. For new authentication, privately generate a separate **short-lived, single-use, non-ephemeral auth key**, scoped to exactly that host's tag. Use preauthorization only for the already verified device, or approve the pending device manually. Never install reusable tailnet-administration OAuth credentials on a host. Provision reviewed SOPS ciphertext with the verified operator and that host's distinct public recipient; no new keys/ciphertext/recipients are generated by this implementation.
3. Declare its SOPS secret in the existing host's top-level module contribution: root-only `0400`, ordinary runtime path `/run/secrets/NAME`, `neededForUsers = false`, and `restartUnits = [ "fleet-tailscale.service" ]`. Set `fleet.tailscale.authKeySecret` to that declaration's name and `enrollmentMode = "auth-key"`. The ciphertext source/key selection must be real. `just secret-check` precedes staging. ThinkPad's existing Wi-Fi/password ciphertext is not a Tailscale credential; the fixture's use of that ciphertext only tests shape/key selection.
4. For an already authenticated, correctly tagged node, select `enrollmentMode = "preserve"`, `authKeySecret = null`; do not reenroll it. Review any retained routing, Serve/Funnel or operator settings before reuse; this code does not silently reset old private state. Only after actual state/recovery and intended-tailnet/live-policy/tag review acknowledge `stateReviewed` and `policyReviewed`. Then change only that host's entry in the `rollout` table in `modules/tailscale/clients.nix` to true and deliberately update the real-host rollout oracle in `modules/validation.nix`. Do not set host `ready` or other review flags as a shortcut.
5. Run canonical checks and the affected commissioned host's readiness/build. Enabling a client adds UDP **41641** for encrypted tunnel transport, not a new application grant. It keeps native netfilter mode `on` (Tailscale manages its own overlay rules), never blanket-trusts the interface, disables Taildrop/Tailscale SSH/webclient/operator/auto-update and route/exit-node advertisement/acceptance, and accepts reviewed tailnet DNS. Host builds never publish tailnet policy. `services.tailscale.*` must not become a second enrollment/preferences writer.
6. With explicit host-operation authorization and verified recovery, activate one commissioned host at a time. The unit uses `--auth-key=file:...` **only in NeedsLogin**; it never force-reauthenticates, resets unknown preferences or submits a key to a pending-approval node. Running nodes retain identity; stopped nodes reconnect using a genuinely bare `up` bounded by external `timeout` (even `up --timeout` triggers the CLI's non-default-settings check). Exact self-tag and running-state checks reject unexpected identity results. Secret/CLI failures have sanitized diagnostics; inspect them privately rather than exposing credentials/login URLs. Network-online ordering and three bounded attempts cover transient startup failures; after exhaustion, correct the cause and explicitly reset/restart the unit, never disable guards.
7. Verify the **actual intended tailnet** in the admin console, unique correct tag, node identity/expiry and successful connection. Test allowed SSH/ICMP and denied reverse/lateral/family flows, unchanged out-of-band access, and stable identity across two authorized boots. A unit reporting success is not these acceptance tests. After successful durable enrollment, switch to `preserve` and remove the consumed runtime key binding/declaration in a reviewed follow-up; don't hand-edit ciphertext/MACs. Expired/revoked node credentials later require an explicit enrollment/recovery decision, not automatic key regeneration.

## Validation boundaries

`just check` covers both-track staged/enabled fixtures, own-track packages, persistence/mount requirements, review/secret/tag/override rejection, native CLI flag availability, offline mocked reconciliation/wrapper behavior, an exact initial-policy oracle with widening regressions, native OpenTofu schema/mock-provider plans and synthetic local encrypted-state/saved-plan tests including wrong-key/plaintext rejection. The encryption test's `terraform_data` apply writes only a temporary local fixture: **no cloud/tailnet provider, host activation, installer or daemon is run**.

These tests cannot establish real key validity/decryption, tailnet identity/plan entitlement, API policy acceptance, tag cardinality, firewall behavior, credentials, networking, hardware boot or restore. Read-only access/scopes, complete diff review and offline backup recovery are now operator-confirmed, separately from these tests. Before a live apply, still confirm exclusive policy-writer control, intended unique fleet-tag assignments and independent administrative recovery access; obtain separately reviewed write credentials and explicit apply authorization, and ensure the reviewed plan remains current. Server policy-engine acceptance and actual allowed/denied flows are not established by the plan. Per-host state/enrollment credentials and remote commissioning remain open; no client review/readiness flag has changed. Deployment and live enrollment are not complete.
