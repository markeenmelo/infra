---
name: deploy
description: Deploy commissioned hosts with deploy-rs through the dedicated deploy account, ordered groups, remote builds and rollback. Use for activation, pre-deployment review and recovery after a failed rollout.
---

# Deploy

Policy lives in `modules/deploy.nix`. There is no guarded runner any more — `deploy-rs` is invoked directly, so every guard below is yours to perform by hand. Reading this authorizes no remote contact: deployment needs explicit authorization for that exact target and mode in the current task.

## Before contact

1. Confirm the exact target and mode. `boot` changes the boot selection without switching the running system; `switch` activates now. A host marked `bootOnly` in `modules/deploy.nix` must be given `--boot`; nothing enforces that any more, so check the plan before you type the command.
2. Groups: `servers` means **racknerd before bastion**; `workstations` holds ThinkPad, which is unready and therefore absent from `deploy.nodes` entirely — `.#thinkpad` is not a valid target, rather than a target that refuses.
3. Confirm the tree is clean and committed (`git status --short` empty) and that the revision is the one reviewed — nothing checks this for you.
4. For every target run `nix eval --no-update-lock-file --json .#deploymentPlan.HOST`, confirm `ready` and `enable`, then `nix build --no-update-lock-file --no-link .#nixosConfigurations.HOST.config.system.build.toplevel`.
5. Confirm by hand what the removed preflight used to probe: the `deploy` login works, its sudo is noninteractive, `/run/deploy-rs` is writable, and the host lists `deploy` in Nix `trusted-users`.
6. Evaluation proves neither installed access, credentials, capacity nor backups.

## Account

The approved account is `deploy`: locked password, restricted SSH keys, private `/var/lib/deploy`, explicit Nix trust and passwordless activation/confirmation sudo. That combination is **root-equivalent**, not a sandbox. Root SSH and agent forwarding stay off; `wheel` keeps its password requirement.

A new account cannot bootstrap itself. For the first access-changing rollout, provision and test the new login through independently verified console or existing access, keep the old path until the new one is proven, and preserve machine SSH and age identities plus off-host recovery.

## Running it

```sh
nix run --no-update-lock-file .#deploy-rs -- \
  --checksigs --no-update-lock-file \
  --targets .#racknerd .#bastion
```

Add `--boot` for a boot-only activation. `--groups servers` filters but does **not** order, so always pass explicit `--targets` in the intended order. Keep `--checksigs`, `--no-update-lock-file`, batch/strict SSH and noninteractive sudo; never pass `--skip-checks`, relax SSH or disable rollback. Remote builds may overlap between hosts.

Nothing now refuses an unready target, an ineligible host, a dirty tree or a `switch` on a `bootOnly` host — `deploy.nodes` still omits unready and deployment-disabled hosts, and that is the only remaining automatic guard.

## Rollback and recovery

`autoRollback` re-activates the previous profile when activation fails. `magicRollback` waits for the deployer to confirm reachability after activation and reverts if it never arrives — which is why an SSH-affecting change can never be deployed without independent console access. A failure late in a multi-target run can roll back hosts that already succeeded.

Rollback restores a system profile. It does not restore data, `/persist`, disks, databases or secrets, and it does not guarantee the next boot. On failure, stop and let rollback finish; inspect console, power and network instead of retrying blindly. A disk operation is never deployment repair.

Afterwards verify the intended generation, both key logins, sudo policy, units, network and persistent mounts. Reboot acceptance is a separate step, especially after a boot-only activation.
