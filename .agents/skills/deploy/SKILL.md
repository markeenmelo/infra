---
name: deploy
description: Safely preflight selected commissioned hosts for locked deploy-rs with explicit closure trust, strict SSH, retained rollback and current operation authorization.
---

# Deploy

Read `../../../AGENTS.md`, `../../../modules/deployment.nix`, `../../../modules/fleet/ready.sh`, target metadata, [current host evidence](../fleet-operations/references/hosts.md#current-status) and [operations/recovery](references/operations.md#deployment-and-recovery). Reading this skill authorizes no remote contact.

## Procedure

1. Confirm exactly one target and `boot` or `switch` intent with the operator. Both servers use distinct off-target signing keys; ThinkPad remains unready/local-only. Current Bastion home removal requires boot-only activation and a separately planned reboot, not a forced live unmount.
2. In the supported locked development shell, complete **all** [manual validation](../validate/SKILL.md) before target contact, including ciphertext checks before staging/evaluation. Inspect `.#fleet` and `.#deploymentPlan`; compare actual package source/revision with independent host policy. No readiness flag or oracle changes to get a pass.
3. Run `bash modules/fleet/ready.sh HOST deploy` and build the commissioned target with `devenv shell build HOST`. The connection account must be configured, keyed and non-root; root remains the system activation user. Resolve all real credential, recovery and trust prerequisites via `../../../secrets/README.md`; pure checks do not decrypt.
4. Verify signed transport and interactive sudo. `LOCAL_KEY` is the selected host's existing readable private signing-key **path**, never key contents, a task input or flake value. Privately derive its public key with `nix key convert-secret-to-public` and compare exact membership in that target's `nix.settings.trusted-public-keys`. Fail on mismatch. No blanket wheel trust, disabled signatures or passwordless sudo shortcut.
5. With current authorization, verify the installed host fingerprint, independent console/old generation, free store/boot space, administrative login and elevation. Keep an existing session for sensitive changes. Stop on an offline machine or unexplained changed key.
6. **The live task and fleet wrapper are removed; no replacement wrapper exists.** The retained `devenv shell deploy ...` only invokes locked deploy-rs, so it does not enforce steps 1–5. Construct/review the exact single-target invocation from locked `deploy --help` only after those steps. Preserve `--interactive`, `--checksigs`, `--no-update-lock-file`, the target's port and strict SSH/liveness options described in the reference; `--boot` only for the agreed boot-only mode. Use a private foreground terminal for signer access and sudo. Never treat successful raw CLI startup as completed preflight.
7. Keep automatic/magic rollback enabled. Dry activation still contacts/copies to targets; it is not local validation. Stage access-changing migrations with old/new paths and a console, rather than disabling recovery or retrying blindly.
8. After an authorized activation, verify intended generation, reachability, both reviewed administrator logins, sudo, units and persistent mounts. A planned reboot and runtime/backup acceptance remain separate. On failure, wait for rollback and inspect through existing access/console; recovery may require an authorized prior-generation selection and independent data restoration.

## Completion

Report exact target/revisions, preflight and actual activation results, remaining runtime/reboot checks and authorization scope. If no operation was authorized, report a local preflight/plan only. No disk operation is a deployment repair.
