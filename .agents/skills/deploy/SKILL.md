---
name: deploy
description: Deploy commissioned hosts with deploy-rs through the dedicated deploy account, ordered groups, remote builds and rollback. Use for activation, deployment preflight and recovery after a failed rollout.
---

# Deploy

Policy lives in `modules/deploy.nix`; the guarded runner is `scripts/devenv/deploy.sh`. Reading this authorizes no remote contact — deployment needs explicit authorization for that exact target and mode in the current task.

## Before contact

1. Confirm the exact target and mode. `boot` changes the boot selection without switching the running system; `switch` activates now. A host with `bootOnly` refuses `switch`.
2. Groups: `servers` activates **racknerd before bastion**; `workstations` holds ThinkPad, which is unready and must make the run refuse rather than be skipped quietly.
3. Complete the full local check sequence in [devenv](../devenv/SKILL.md) — the task runs `scripts/devenv/preflight.sh` itself and refuses a dirty or changed tree. Also run `devenv shell ready HOST` and `devenv shell build HOST` for every target.
4. Local checks prove evaluation, not installed access, credentials, capacity or backups.

## Account

The approved account is `deploy`: locked password, restricted SSH keys, private `/var/lib/deploy`, explicit Nix trust and passwordless activation/confirmation sudo. That combination is **root-equivalent**, not a sandbox. Root SSH and agent forwarding stay off; `wheel` keeps its password requirement.

A new account cannot bootstrap itself. For the first access-changing rollout, provision and test the new login through independently verified console or existing access, keep the old path until the new one is proven, and preserve machine SSH and age identities plus off-host recovery.

## Running it

```sh
devenv shell -- deploy TARGET MODE "DEPLOY TARGET MODE"
```

or the equivalent `devenv tasks run deploy:run` inputs. Both take the same guarded body: exact confirmation string, clean reviewed commit, full preflight, eligibility and boot-only checks, then installed login, sudo and Nix-trust probes before expanding ordered targets.

Raw `deploy-rs` skips all of that. If it is ever used under authorization: `--groups servers` filters but does not order, so pass explicit `--targets .#racknerd .#bastion`; keep `--checksigs`, `--no-update-lock-file`, batch/strict SSH and noninteractive sudo; never pass `--skip-checks`, relax SSH or disable rollback. Remote builds may overlap between hosts.

## Rollback and recovery

`autoRollback` re-activates the previous profile when activation fails. `magicRollback` waits for the deployer to confirm reachability after activation and reverts if it never arrives — which is why an SSH-affecting change can never be deployed without independent console access. A failure late in a multi-target run can roll back hosts that already succeeded.

Rollback restores a system profile. It does not restore data, `/persist`, disks, databases or secrets, and it does not guarantee the next boot. On failure, stop and let rollback finish; inspect console, power and network instead of retrying blindly. A disk operation is never deployment repair.

Afterwards verify the intended generation, both key logins, sudo policy, units, network and persistent mounts. Reboot acceptance is a separate step, especially after a boot-only activation.
