---
name: deploy
description: Safely preflight and deploy selected commissioned hosts using locked deploy-rs, verified Nixpkgs tracks, explicit closure trust and preserved rollback and recovery mechanisms.
---

# Deploy

## Purpose / when

Prepare or perform a deploy-rs activation. Reading this skill never authorizes remote contact; require current explicit approval before deployment, dry activation, reboot or any connectivity-changing command.

## Prerequisites

Read `../../../AGENTS.md`, `../../../modules/deployment.nix`, `../../../modules/fleet/ready.sh`, `../../../docs/hosts.md`, `../../../docs/operations.md#deployment-and-recovery` and the target's metadata. Read [current access and rollout status](../../../docs/hosts.md#current-status), not the initial root-only inventory: Racknerd's temporary non-root bootstrap is not declarative commissioning. Targets deny root SSH; a disabled Tailscale rollout must preserve backing state without requiring an active daemon. Verify the separately authorized access/routing/credential transition before activation. Servers opt into deploy-rs only after commissioning; thinkpad stays local-only. Require real commissioned NixOS, SSH account/endpoint/port, verified host key, working elevation, closure trust, backups and independent recovery access. Use `nix-research` after deploy-rs/Nix API changes and inspect the **locked** `deploy --help`.

## Procedure

1. From repository root enter `nix develop --no-update-lock-file`. Confirm exactly which host/subset is intended and whether it is online. Desktop eligibility is `deployment.enable`, not an assumption that all fleet entries should receive every change.
2. Run `just check` before remote contact. Inspect `just inventory`; compare the target's track/revision and actual `nixpkgsPath` with intended input. `validation.nix` independently enforces the host-track policy; never change the oracle merely to bypass an unexpected track.
3. Run `bash modules/fleet/ready.sh HOST deploy`. Inspect `nix eval --json .#deploymentPlan | jq .`; resolve all placeholders. `deployment.sshUser` must be a configured non-root account with public keys, while `deployment.profileUser` remains root for system activation. Never enable SSH root login to bypass the non-root deployment assertion. Build with `just build HOST` if prebuilding is appropriate. Review SOPS identity custody/recipients/early decryption and signing keys separately via `../../../secrets/README.md`: pure checks do not decrypt or verify working credentials. Missing password bindings and unreviewed identities must continue to block commissioning.
4. Confirm closure upload trust and elevation independently. `transport = "trusted-user"` is root-equivalent Nix access; `"signed"` needs pre-provisioned target public trust and an operator `LOCAL_KEY`. Interactive sudo/doas must work as configured. Never add global wheel trust, disable signature checks or store credentials in Git to get past a deployment failure.
5. With authorization, verify SSH fingerprint/reachability and console access. Keep an existing session for sensitive changes. If offline, stop or deliberately choose an online subset; do not remove rollback safeguards or retry blindly.
6. Execute only the selected approved scope:
   ```sh
   just deploy racknerd
   # Approved subset, after individual preflights:
   deploy --targets .#racknerd .#bastion -- --no-update-lock-file
   # All eligible nodes, only if that whole scope was authorized:
   just deploy-fleet
   ```
7. Preserve automatic and magic rollback. `--dry-activate` still contacts/copies to the target. SSH changes should preserve old/new access in a staged migration. If unavoidable, a separately authorized console-controlled maintenance may use `--magic-rollback false`; never persist that override in defaults. Review upstream subset `--rollback-succeeded` behavior before intentionally changing it.
8. Confirm activation, reachability, intended generation, service health and persistent mounts. A future reboot/hardware acceptance test needs its own maintenance plan. Do not confuse successful activation with data restore or verified bootability.
9. If activation or confirmation fails, wait for rollback and inspect status via existing access/console. Stop on unexplained host-key change. If necessary and authorized, use console generation selection or `sudo nixos-rebuild switch --rollback`; application data may need separate recovery.

## Completion criteria

Report exact target(s), locked revisions, preflight results, activation/health results and remaining reboot/runtime checks. If unreachable or unauthorized, completion is a documented preflight/plan only, never a claimed deployment.

## Common failures

Wrong/unknown endpoint, expired credentials, missing runtime password hash, unsigned closure rejection, sudo/run0 incompatibility, offline desktop, confirmation timeout after SSH changes or service data migration breaking rollback. Consult research and operations; no disk formatting or secret bypass is a valid deployment repair.
