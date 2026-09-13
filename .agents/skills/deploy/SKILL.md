---
name: deploy
description: Preflight and deploy commissioned hosts through the dedicated root-equivalent deploy account, ordered groups, remote builds and retained automatic/magic rollback.
---

# Deploy

Read `../../../AGENTS.md`, `../../../modules/deploy.nix`, `../../../scripts/fleet/ready.sh`, [current host evidence](../fleet-operations/references/hosts.md#current-status) and [operations/recovery](references/operations.md#deployment-and-recovery). Reading this skill authorizes no remote contact.

## Procedure

1. Confirm the exact host/group and `boot` or `switch` operation. `servers` orders **Racknerd before Bastion**; `workstations` includes ThinkPad but does not commission it. Never silently skip an ineligible group member. Bastion's pending home-bind removal remains boot-only with a separately authorized reboot.
2. Complete all [local validation](../validate/SKILL.md), including ciphertext inspection before Nix copies sources into the store. Run deployment readiness and build each commissioned target. Inspect `.#fleet`, `.#deploymentPlan` and `.#deploymentGroups`. Local checks cannot establish installed access, credentials, capacity or backups.
3. The approved account is `deploy`, a locked-password system user with the two existing restricted SSH keys, private ephemeral `/var/lib/deploy`, explicit Nix trust and passwordless activation/confirmation sudo rules. This is **root-equivalent**, not a security sandbox. Wheel still requires a password; `marcos` retains password/fingerprint administration only on ThinkPad. Root SSH, forwarding and deploy-key PTYs stay prohibited.
4. **Stage the first access-changing rollout through independently verified console/old access.** The accepted servers do not yet prove that `deploy` exists. A new account cannot bootstrap itself; the removed `marcos` account must not be your only recovery path. Preserve machine SSH/age identities, old generation and off-host recovery. See [transition](references/operations.md#minimal-server-transition--2026-09-13).
5. With authorization, verify installed host fingerprints, both selected key logins, `sudo -n -l`, target Nix trust, store/build/boot capacity and independent console access. Keys/known-host paths stay in private operator SSH configuration, not task inputs. Remote builds use target packages and durable `/nix/var/nix/builds`, not the small tmpfs root. No signing-key read is needed for the new trusted-user policy; retained old public signers are recovery compatibility, not additional trusted users.
6. Raw deploy-rs does not implement the repository's whole preflight or group order. Native `--groups servers` filters but sorts nodes differently; select explicit ordered `--targets .#racknerd .#bastion` for ordered activation. Its remote builds may run concurrently. Do not pass overrides disabling rollback/signatures, changing identities, using `--skip-checks` or relaxing SSH. Preserve `--checksigs`, `--no-update-lock-file`, noninteractive sudo and strict/batch SSH.
7. Verify intended generation, separate key logins, sudo policy, services and persistent mounts after an authorized operation. Reboot acceptance is separate, particularly after boot-only activation. Stop on any failure and allow rollback; do not retry blindly or use a disk operation as deployment repair.

## Completion

Report exact targets/order/mode, revisions, actual validation/activation results, remaining boot/access/backup checks and authorization scope. Configuration removal is not home-data erasure or credential revocation. No remote operation occurred merely because this skill or a local build passed.
