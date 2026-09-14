---
name: tailscale
description: Hosted Tailscale control plane, encrypted local OpenTofu plans, operator-only custody and separately authorized NixOS enrollment. Use for modules/tailscale.nix, opentofu/tailscale/, the policy or tailnet task.
---

# Hosted tailnet

Read [AGENTS.md](../../../AGENTS.md), [secrets](../../../secrets/README.md) and, before activation or identity persistence, [storage](../storage/SKILL.md) and [deploy](../deploy/SKILL.md). Run commands from the repository root in the locked development shell. Repository edits, evaluation, builds and read-only API validation authorize no apply, tagging, key issuance, host activation, mounting, enrollment, logout or deletion.

## Boundaries

- `modules/tailscale.nix` contributes to NixOS `base`: native daemon/package, UDP 41641 and root-owned `0700` `/var/lib/tailscale` persistence. There is no trusted firewall interface or host auth-key delivery. MagicDNS is accepted; routing, exit nodes, Tailscale SSH/webclient and automatic client updates are disabled through the native set unit. OpenSSH authentication, public/LAN access and deploy-rs endpoints/rollback remain unchanged; ThinkPad remains outside deploy-rs.
- `opentofu/tailscale/main.tf` pins OpenTofu 1.12.6 and official provider 0.29.2. The development pin supplies OpenTofu. `.terraform.lock.hcl` must remain tracked; initialize task runs with `-lockfile=readonly`. No flake/devenv pin changes are part of this capability.
- `assets/tailscale/policy.hujson` is the complete policy: only `tag:admin-client` → `tag:server` TCP 22, with `ssh = []`. The administrator-owned `tag:infra-provisioner` owns both operational tags and has no network grant. It is the existing OAuth client's bootstrap tag, manually added before adoption; never assign it to a machine. Tags, not hostnames or Git entries, authorize access. Ordinary accounts, including Nara, get no application access. No routes, exit nodes, Serve/Funnel or unspecified Services are managed.
- Grafite is verified node `nV2TinpBxq11CNTRL`; Nara PC is `nLpcNBLSGC11CNTRL`. The Grafite tag resource imports by node ID and prevents destruction. Tagging Grafite removes personal-user identity and Taildrop; the user accepted this only for a separately authorized apply. Never delete/logout/re-enroll either device. Removing the last tag does not restore personal ownership. Nara's separate member account is untouched.
- Import existing policy, settings, MagicDNS, search paths and Grafite tags. Preserve device approval on, auto-updates off, 180-day default expiry, user approval off, external-tailnet joining restricted to admins and regional routing/posture collection off. Mark policy externally managed without inventing a URL. Omitted HTTPS/logging settings are optional/computed in this provider and must be preserved in plan review.
- Provider 0.29.2 rejects empty `tailscale_dns_nameservers`. With user approval, the task checks `GET .../dns/nameservers` equals `{"dns":[]}` and `GET .../dns/split-dns` equals `{}` before both plan and apply, failing on drift; it never writes either setting. MagicDNS/search paths use granular resources, not the alpha aggregate resource. Empty global/split DNS is guarded, not owned in state.
- Exactly three single-use keys: ThinkPad → admin-client; Racknerd/Bastion → server. They are preapproved, non-ephemeral, expire after 86400 seconds and have `recreate_if_invalid = "never"`. Consumption/expiry must not trigger renewal in an ordinary plan. Later reinstall/renewal requires explicit replacement review. No existing credentials are revoked.

## Custody and recovery

The only source is `secrets/tailscale/operator.yaml`, copied unchanged from the reviewed operator-local ciphertext. It has exactly the existing operator recipient and four encrypted fields: OAuth client ID/secret, tailnet ID and `TF_VAR_state_passphrase`. Never select it in sops-nix or send OAuth credentials to hosts. Shell entry, dotenv, SecretSpec, task outputs and Nix never load these secrets. Review all four encrypted scalars, the encrypted MAC and sole age recipient by eye before staging any change.

Only explicit operator processes decrypt with SOPS. The task requests read-only OAuth scopes for validation/planning, then a write-scoped token only for an explicitly selected apply. Tokens stay in process memory/provider environment, never arguments. Do not enable provider debug logs, shell tracing, task exports or plaintext `tofu show -json`/`output` in logs/chat.

Runtime root: `${XDG_STATE_HOME:-$HOME/.local/state}/infra/tailscale`, outside the checkout and store. Use operator-owned `0700` directories and `0600` files, no symlinks or writable ancestry. The task refuses unsafe existing paths; it never recursively repairs permissions. `data/` holds `TF_DATA_DIR`; `terraform.tfstate` and its native backups hold the local backend; `plans/review-*/` holds each encrypted `plan.tfplan`, a revision/hash manifest and an attempted marker. Use only the default workspace. State and saved plans have enforced PBKDF2/AES-GCM encryption, no plaintext fallback. Native local-backend locking remains enabled.

Back up and independently demonstrate recovery of the operator age identity, passphrase and encrypted backend before applying. Git ciphertext alone is insufficient; persistence/rollback is not a backup. Never change the passphrase or encryption identifiers blindly. If the backend later moves, use reviewed native backend migration, not file deletion, re-import-and-reissue or an ad-hoc state rewrite.

## Review and plan

1. Refresh device inventory/settings through read-only authenticated API access or the admin console. Recheck both exact node IDs, owner/OS, tags, authorization, routes and expiry. Stop on identity discrepancies or unexpected drift. Record tailnet IPs for later connection tests. No hostname lookup substitutes for identity. Preserve both existing nodes and Nara's membership.
2. Run the local verification below, inspect the entire diff, then obtain user review and a commit. Do not commit unless asked. Both task actions require a clean, reviewed, committed revision; cleanliness cannot establish human review by itself.
3. Explicitly generate a saved plan:

   ```sh
   devenv tasks run tailnet:deploy --input action=plan
   ```

   The task rejects missing/unknown inputs before secret access. It checks private paths, decrypts inside the operator process, checks empty DNS and submits the actual policy to `POST /api/v2/tailnet/{tailnet}/acl/validate`. HTTP 200 alone is insufficient: success must be `{}`; failed tests also return HTTP 200. It then initializes with the checked-in lockfile, validates HCL and saves an encrypted plan plus the commit/hash manifest. Provider planning itself only syntax-checks the policy, not native access tests.
4. Inspect the displayed plan and, if needed, native `tofu show SAVED_PLAN` in a private SOPS-authenticated process with the same `TF_DATA_DIR`. Never print sensitive JSON. Expect only imports, the narrow policy/settings changes, Grafite tagging and three key creations. No existing-device deletion, Nara change, extra tags or unobserved setting changes. Inspect state/plan encryption envelopes without decrypting their contents into logs. State may not exist until the first apply. The saved plan's source must remain the reviewed commit.

## Apply — separate authorization

Confirm independent recovery and authorize **the exact saved plan**, including Grafite's transition and key issuance:

```sh
devenv tasks run tailnet:deploy --input action=apply --input plan=/ABSOLUTE/PRIVATE/SAVED_PLAN
```

The selected file must be a task-created `plans/review-*/plan.tfplan`, private, hash-matching and from the current clean revision. Validation runs again. The task applies that saved plan directly: no arbitrary flags, interactive approval, `--auto-approve`, automatic retries, host deployment or enrollment. An attempted marker prevents replaying a plan after any apply attempt.

Policy precedes settings/Grafite tagging; keys depend on policy and device-approval settings. This is not atomic. On partial failure, stop, inspect live configuration and encrypted state, then generate/review a new plan. Do not remove the marker, destroy resources, revoke credentials or blindly retry. Inspect only key metadata, not values, after success. Verify both existing nodes remain present; inspect Grafite's expiry rather than assuming tagging changes it. Newly tagged nodes normally have non-expiring node keys; this is separate from the 24-hour enrollment-key lifetime.

## Host activation and enrollment — separate authorizations

For each host, first establish actual permitted activation access and independently verified console/recovery. Preserve trusted host keys and LAN/public SSH. A VPS, local address or successful build proves none of these.

Before activating the new persistence binding, inspect existing `/var/lib/tailscale` and `/persist/var/lib/tailscale` through authorized access, without printing identity material. Back up the existing identity. If state exists, preserve/seed that same host's state with root ownership and `0700` mode before binding; if both locations exist and differ, stop. Never overwrite or copy identities between hosts. Mounting/seeding, service stop/restart and activation each need explicit authorization. Use existing deployment procedures for commissioned servers and separately approved local activation for ThinkPad; no endpoint switch is needed.

After an authorized successful tailnet apply, extract only the selected host's key into a private runtime file in an operator terminal. This uses native OpenTofu output, not task/chat output. Run from the repository root; choose one host and verify your state directory is the same protected root initialized by the task. Keep the documented paths free of single quotes when using this command string.

```sh
(
  set +x
  set -euo pipefail
  umask 077
  host=thinkpad # or racknerd or bastion, one at a time
  state="${XDG_STATE_HOME:-$HOME/.local/state}/infra/tailscale"
  key=$(mktemp "${XDG_RUNTIME_DIR:?}/tailscale-${host}.XXXXXX")
  tofu=$(command -v tofu)
  sops exec-env --pristine secrets/tailscale/operator.yaml \
    "TF_DATA_DIR='$state/data' TF_CLI_CONFIG_FILE=/dev/null '$tofu' -chdir=opentofu/tailscale output -json enrollment_keys" \
    | jq -er --arg host "$host" '.[$host] | select(type == "string" and length > 0)' > "$key"
  printf 'Private one-use key file: %s\n' "$key"
)
```

Use an operator-owned `0700` runtime directory; the file remains `0600`. Transfer only this host's file through separately authorized trusted access to root-only runtime storage on that host. The OAuth secret, passphrase and other hosts' keys stay with the operator. Do not put key values in command arguments, shell history or chat.

After separately authorizing **that host's** enrollment, and only if it needs enrollment rather than preserving an existing identity:

```sh
sudo tailscale up --auth-key=file:/ABSOLUTE/ROOT-ONLY/KEY_FILE
```

The pinned clients support `file:`. Settings are applied by the native set unit, not `extraUpFlags` without `authKeyFile`; never use `tailscale set` to manage tags. Verify the set unit succeeded and effective preferences match `modules/tailscale.nix`; stop if it failed. Verify automatic device approval, intended operational tag, non-ephemeral identity, no unexpected routes or Tailscale SSH, then remove the one-use files on operator and host. A consumed/expired key is not permission to generate another. Never log out an existing identity just to make enrollment work.

From ThinkPad **and** Grafite, test real SSH to both servers using trusted OpenSSH keys. From Nara PC, test TCP 22 to their recorded tailnet IPs and confirm denial (not merely DNS failure). Test existing LAN/public SSH independently. Finally, with separate restart/reboot authorization, verify the same identity survives without another key and record tagged-node expiry behavior. Stop on lost access or unexpected changes.

## Local/read-only verification

- In the locked shell: `nix fmt`, `git diff --check`, `nix flake check --no-update-lock-file -L`. Inspect every changed file and `.claude/skills/tailscale` link. Flake check evaluates outputs only.
- For each of `thinkpad`, `racknerd`, `bastion`: `nix eval --no-update-lock-file --json .#fleet.HOST` and `nix build --no-update-lock-file --no-link .#nixosConfigurations.HOST.config.system.build.toplevel`. Inspect native Tailscale settings, root-only persistence and unchanged deploy/SSH boundaries. No boot, network or recovery proof follows.
- Set `TF_DATA_DIR` to a private validation directory under the runtime root. Run `tofu -chdir=opentofu/tailscale init -backend=false -lockfile=readonly -input=false`, then `fmt -check` and `validate`. These need no real credentials and must not create a saved deployment plan before review/commit.
- Run `shellcheck scripts/devenv/tailnet.sh` and `devenv tasks run tailnet:deploy --input action=invalid`; it must fail before secret access/API calls.
- Submit the final policy using a token restricted to `policy_file:read devices:core:read devices:posture_attributes:read`; require HTTP 200 and `{}`. Submit an in-memory variant replacing the grants with `src=["*"], dst=["*"], ip=["*"]`; require native deny-test failures, not an authentication/syntax failure. Never POST either policy to the live `/acl` update endpoint during verification. Test sources use the two verified ordinary accounts because autogroup selectors are not valid test sources.
- Only after user review/commit, generate and inspect the saved plan and encryption envelopes. Applying it, host activation, recovery/access and persistence checks remain separately authorized operations, not local verification.

Upstream references at the chosen boundaries: [provider v0.29.2](https://github.com/tailscale/terraform-provider-tailscale/tree/v0.29.2/docs), [OpenTofu encryption](https://opentofu.org/docs/language/state/encryption/), [OAuth scopes](https://tailscale.com/kb/1623/trust-credentials), [policy syntax](https://tailscale.com/kb/1337/policy-syntax). Recheck these when changing dependencies.
