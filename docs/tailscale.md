# Tailscale: staged clients and declarative tailnet

See [ADR 0009](adr/0009-tailscale-and-opentofu.md) and [dated API evidence](research.md#staged-tailscale--opentofu--2026-09-10).

## Current status — 2026-09-10

**Prepared, not enrolled or applied.** The user explicitly selected disabled rollout while bootstrap facts are unresolved. All four compositions include the capability, but `fleet.tailscale.enable = false`: no daemon, enrollment unit, new firewall port or persistence bind is added to a real host. Existing commissioning/review flags are unchanged. `just tailscale-inventory` reports separate rollout prerequisites; `just inventory` still reports OS commissioning.

Authorized read-only SSH used previously verified host keys, strict checking and no key updates/forwarding. No deployment, reboot, state read/copy/reset, secret decryption or tailnet API operation occurred:

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

These are future operator steps, not commands run by checks or permission to apply now:

1. Supply the exact existing tailnet ID. Independently verify administrator recovery and export/review its existing policy and DNS settings. Disable any prior GitOps publisher/other OpenTofu state managing the policy. Prefer the admin console's **Prevent edits** setting plus a repository reference; it permits emergency overrides, which must be reconciled into Git before the next apply. Provider updates replace the whole document without optimistic concurrency. Local locking protects only this state, not another writer.
2. Create/review narrowly scoped automation credentials for policy/DNS read/write. Supply `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET` privately via the provider environment. Do not use enrollment keys as API credentials, put secrets in `.tfvars`, enable TF debug logging or paste them into an agent conversation. See [secret handling](../secrets/README.md#safe-operator-workflow).
3. Create a high-entropy encryption/recovery passphrase in protected storage, with an independent recovery copy. Keep encrypted state/backups and the recovery key independently recoverable. A path/key prompt is not proof of tested recovery. State and saved plans use enforced PBKDF2/AES-GCM with **no plaintext fallback**; the passphrase is an ephemeral variable. Backend working metadata is not secret storage. Encryption does not hide values from an authorized CLI operator or protect against lost/corrupted/stale state.
4. In the locked shell, use a private terminal to supply runtime inputs, without entering values into shell history:

   ```sh
   read -r -p 'Verified tailnet ID: ' TAILSCALE_TAILNET
   export TAILSCALE_TAILNET
   export TAILSCALE_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/infra-tailnet"
   read -r -s -p 'Recovery passphrase: ' TF_VAR_state_passphrase; printf '\n'
   export TF_VAR_state_passphrase
   # Supply the scoped provider credentials privately, not as command arguments.
   just tailnet init
   ```

   The wrapper binds a new empty private `0700` directory to that tailnet. State, backups, saved plans and provider working data stay **outside the checkout/Nix store**. Existing nonempty/unbound directories require recovery review; permissions are never silently repaired. No auto-loaded `.tfvars` or override files, alternative workspaces, TF_CLI_ARGS overrides, debug logging or TF_ENCRYPTION overrides are accepted. The environment is transient: unset credentials/passphrase after use. State and plan output may disclose network metadata, so review privately.
5. **After authorizing read-only API access**, import both existing singletons into encrypted local state:

   ```sh
   just tailnet import-policy
   just tailnet import-dns
   just tailnet plan
   ```

   Imports change local state, not the live tailnet. A plan contacts the API but does not apply. Review the complete policy/DNS diff and policy tests, verify one intended node per privileged tag, preserve out-of-band access, and authorize the exact change separately. A saved plan remains at `$TAILSCALE_STATE_DIR/change.tfplan`; no older plan is silently overwritten. Provider/server validation on apply is still required; offline mocks are not Tailscale's policy engine.
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

These tests cannot establish real key validity/decryption, tailnet identity/plan entitlement, API policy acceptance, tag cardinality, firewall behavior, credentials, networking, hardware boot or restore. Tailnet ID, scoped API credentials, encrypted-state recovery, per-host state/credential reviews and remote commissioning remain open. Deployment and live enrollment are not complete.
