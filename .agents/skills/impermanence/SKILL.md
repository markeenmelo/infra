---
name: impermanence
description: Audit, add or migrate persistent machine, SSH, user and service state for the fleet tmpfs-root systems without broadly persisting ephemeral directories.
---

# Impermanence

## Purpose / when

Decide what must survive reboot when adding a service/user, changing storage, diagnosing lost state or commissioning a host.

## Prerequisites

Read `../../../AGENTS.md`, `../../../modules/storage/persistence.nix`, `../../../modules/logging.nix`, `../../../docs/hosts.md`, `../../../docs/bootstrap.md` and the owning feature. Research current impermanence/systemd initrd behavior via `nix-research` if touching boot/mount APIs or updating inputs. Obtain a migration backup and state ownership facts.

## Procedure

1. Classify each path: declaratively reproducible, disposable cache, identity/security material, valuable user data, service state, diagnostic history or external NAS data. Persist only what has a reason; do not persist `/etc` or `/var` wholesale.
2. Audit `nix eval --json .#fleet.HOST.persistence | jq .`. Remember the report lists declared bind/symlink paths; `/nix` is a separate persistent filesystem and direct contents of `/persist` also survive. Removing a declaration does not delete its backing data.
3. Review this checklist:
   - Machine identity: unique `/etc/machine-id`, NixOS user/group allocation state, random seed and timer stamps.
   - SSH: all configured host-key pairs; fingerprints and private-key permissions; never copy another machine's keys.
   - Service/application state: data directories, ownership, dynamic users, queues/databases, schema migrations and secret references. Required data mounts must fail closed rather than falling back to tmpfs directories.
   - User state: documents, game saves, credentials and homes. Workstations intentionally preserve `/home`; the current laptop has a separate early-mounted home filesystem, so set `fleet.workstation.homePersistence = "filesystem"` and do not also bind `/home` or its children. Fresh-install workstation policy may use an impermanence bind instead. Server home state is not persistent by default.
   - Logs: existing bounded server journal policy; justify any extra retention and space budget.
   - Recovery: what a reboot loses, what deployment rollback does not restore, whether backups and console recovery are tested.
4. Add state beside its owning feature through `environment.persistence."/persist".directories` or `.files` in its deferred NixOS value. Specify directory owner/group/mode where defaults are inappropriate. SOPS delivers declared secrets only at activation; encrypted source files may enter the store, decrypted values/private identities may not. Follow `../../../secrets/README.md`: the dedicated age identity uses a direct early `/persist/var/lib/sops-nix/` runtime path, not a late bind. Never persist `/run/secrets*`, generate/rotate identities implicitly or import SSH keys by default.
5. Verify root remains genuinely ephemeral and every backing/ephemeral filesystem involved is `neededForBoot`. Preserve systemd initrd compatibility; do not paste obsolete `postResumeCommands` root-wiping examples. `/nix` must remain a real mounted durable subvolume, not an impermanence directory binding.
6. Plan migration **before reboot**: snapshot/backup existing state, populate correct persistent backing paths with correct ownership/permissions, seed existing machine/SSH identities when appropriate, verify runtime password/secret files. Do not execute migration without current authorization.
7. Stage and run `devenv tasks run repo:fmt`, `devenv tasks run repo:check-full`. Inspect the changed inventory and assertions for duplicates or missing mounts; build affected commissioned systems if possible. For changes spanning reusable modules, validate both tracks.
8. Under separate authorization on test hardware/VM or a maintained console, verify ephemeral markers disappear, persisted markers and identity survive two boots, and applications find their state. Never claim this runtime check from evaluation alone.

## Completion criteria

Every added persistent path has an owner/reason/migration plan, inventory is auditable, both-track checks pass, and runtime/restore verification is either recorded or explicitly pending.

## Common failures / safety

Missing early mounts, duplicated deferred imports, broad persistence, unexpected symlink/file behavior, state copied after rather than before reboot, wrong user ownership, unpersisted service secrets or installing `/nix` on tmpfs. Do not fix these by disabling assertions or wiping backing state. Persistence is not encryption, backup or rollback of application data.
