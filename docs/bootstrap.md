# Commissioning a host

This runbook turns existing compositions into real configurations. **It is not authorization to touch disks or deploy.** Work from a rescue environment/local console when installing or changing boot, storage or networking. Preserve an independently tested backup and a recovery path.

## 1. Gather facts before editing

For each host, record outside public Git if sensitive:

- Original installation `system.stateVersion` (or deliberate initial release for a new installation).
- Actual hardware-generated configuration, firmware boot mode, required initrd modules, CPU/graphics/firmware decisions. Do not infer these from “ThinkPad”, “VPS” or a hostname.
- Verified **whole OS disk** by-id identifier, model/serial/capacity and an explicit list of valuable data disks that are **not** that disk. Stable by-id may not be available on some providers: do not invent one; adapt the storage capability after obtaining an equally stable, independently verified identifier.
- Networking, provider requirements, IPv4/IPv6/DNS/routing, public/private interface firewall policy, SSH reachability and rescue-console access. The base deliberately disables implicit DHCP; supply the actual policy. Workstations use NetworkManager but still need their network policy reviewed.
- Real administration and interactive account names, public-key fingerprints, privilege policy, password-hash provisioning, closure trust.
- Desktop/session, GPU/driver and firmware choices for interactive hosts; gaming software/licensing/controllers for `dino`. Nothing selects a DE, GPU vendor, Steam, Gamescope, launchers or performance tweaks implicitly.
- For `bastion`: independent NAS data inventory, existing filesystem/topology facts, restore plan and future service mount requirements. A functioning OS must not imply approval to alter NAS storage.

On the **target**, read-only inventory commands include:

```sh
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL,UUID
findmnt
ls -l /dev/disk/by-id/
test -d /sys/firmware/efi && echo UEFI || echo 'Verify BIOS/provider boot mode'
```

Do not publish captured output indiscriminately. Before a new install, `nixos-generate-config --no-filesystems --root /mnt` can generate hardware information **after mounting the intended target**; it writes configuration files but does not partition disks. Review it outside `modules/` first. This agent has not run it against any fleet machine.

## 2. Add facts as top-level modules

Create files naming their concern, e.g. `modules/hardware/thinkpad.nix`, `modules/storage/thinkpad.nix`, `modules/access/thinkpad.nix`. Paths are organizational, not import rules. Each file contributes to the same deferred `fleet.hosts.thinkpad.module` value. Do not place a raw lower-level generated `.nix` file in the repository and import it from a host; adapt its reviewed contents into the deferred value.

A safe starting fragment (these values intentionally **do not** unblock deployment):

```nix
{
  fleet.hosts.thinkpad.module = {
    fleet.installation = {
      stateVersion = null;
      hardwareReviewed = false;
      networkReviewed = false;
    };
    fleet.osDisk = {
      device = null;
      confirmed = false;
      bootMode = null;
      espSize = null;
      efiCanTouchVariables = null;
    };
  };
}
```

Replace `null` only with verified choices. Add actual kernel/initrd/network settings in the appropriate deferred module. Exclude generated filesystem/swap definitions when disko owns them; no partition UUIDs or swap are assumed here. Generated `nixpkgs.hostPlatform` should agree with required host metadata. Keep `stateVersion` in `fleet.installation.stateVersion`, which sets the NixOS option; do not give it a second, conflicting direct definition.

No one-time value comes from the dev shell's Nixpkgs, another host, or a hardware scan of the administration machine. User preference settings (timezone, locale, keymap, desktop) should also be deliberate rather than inferred.

## Access and secrets

`modules/access.nix` defines an immutable, initially locked account policy:

1. Supply `fleet.access.admin` and **public** `fleet.access.authorizedKeys`; verify with the owner's fingerprint. Root login and SSH passwords remain disabled.
2. For password-based console/sudo, provide `fleet.access.passwordFile`, a runtime string under `/persist/secrets/` containing a password hash. Stage that file securely, owned by root and mode `0600`, with its containing directory `0700`, **before installation/activation**. Its bytes must never be in Git or interpolated into a Nix derivation. Existence and correctness cannot be verified by pure evaluation.
3. Alternatively, explicitly choose `fleet.access.passwordlessSudo = true`; this grants root-equivalent privilege to that account. Do not enable it merely to pass a check. Desktops need working interactive password/login arrangements even if SSH administration works.
4. Configure actual interactive users through normal NixOS user options in host/user features; `dino` need not use the admin account for gaming and must not receive wheel rights implicitly. Acknowledge `fleet.workstation.usersReviewed` only after accounts/privileges are checked. `/home` persists on workstations. Server home state is ephemeral unless separately declared.
5. Deployment requires metadata `sshUser`, `hostname` and a deliberate `transport`:
   - `trusted-user`: explicitly adds the SSH account to `nix.settings.trusted-users`. **Nix trust is root-equivalent even when sudo still prompts.**
   - `signed`: provision an operator signing key outside this repository, add its public counterpart to the target's `nix.settings.trusted-public-keys`, and supply `LOCAL_KEY` when deploying. Do not disable signature checking. Verify this path before relying on it remotely.
6. Default escalation is interactive `sudo -u`. For automation use an explicitly reviewed passwordless elevation policy and `interactiveSudo = false`. `doas -u` requires separately configuring doas; selecting a command does not configure authorization. No secrets-management backend is claimed or included.

Future service secrets belong in runtime files delivered by a separately researched secret-management capability. Keep that boundary distinct from Nix expressions, source paths and public-key metadata. LUKS is **not** implemented in the baseline: before storing laptop credentials or sensitive server state, deliberately accept that risk or replace the OS layout with a reviewed encrypted design and recovery-key plan.

## 3. Resolve capability-specific blockers

`just inventory` explains every unresolved field. Hardware/network review, OS disk confirmation, desktop/user/gaming choices and provider/NAS acknowledgement fields are human review barriers, not automatic discovery.

Supply deployment metadata through `fleet.hosts.<name>.deployment`, independently of the NixOS module. Servers opt in already; desktops do not. Keep `ready = false` during discovery. Once every fact is supplied, run:

```sh
git add flake.nix flake.lock modules
just fmt
just check
nix eval --json .#fleet.thinkpad | jq '{missing,failedAssertions}'
```

An unready host still has its commissioning assertion. Only after resolving all other issues set `fleet.hosts.thinkpad.ready = true` in a commissioning/identity module, then rerun `just check` and `just ready thinkpad`. Merely setting ready with missing fields makes validation fail; it never overrides them. Source-control facts before installing; retain the exact lock file and recovery generation.

## Storage and installation

**Everything below the explicit execution boundary is a manual maintenance-window operation. Disko may erase the entire selected disk, including existing partitions and boot entries. It is not a migration tool. Never run it during ordinary deployment.**

The baseline requires OS-disk confirmation, firmware choice and an explicitly sized ESP for UEFI. UEFI additionally requires `fleet.osDisk.efiCanTouchVariables`: `true` permits bootctl to create/update NVRAM entries; `false` avoids those writes and requires verifying the firmware boots the installed fallback EFI path. Neither is inferred from machine model. It uses a tmpfs `/`, Btrfs `@nix` at `/nix` and `@persist` at `/persist`. BIOS additionally uses `@boot` and a standard GPT BIOS metadata partition; UEFI uses a vfat ESP. No sizes of existing disks/filesystems are asserted. “100%” means the chosen remainder policy, not an observed capacity.

Only `disko.devices.disk.os` is allowed by this capability. NAS data disk definitions, multi-device pools, shares and backup jobs are absent. **For `bastion`, disconnect valuable data disks during initial OS provisioning where practicable**, independently compare serials, and have another person review the boundary. If an OS and valuable data share the same disk, **do not use this baseline**; design a migration that preserves data instead.

### Non-destructive planning

After real facts and readiness are approved:

```sh
just check
just ready bastion
nix eval --json .#fleetConfigurations.bastion.config.disko.devices.disk.os.device
nix eval --json .#fleetConfigurations.bastion.config.fileSystems | jq .
just disk-plan bastion
less result-disko-bastion
```

`disk-plan` builds a dependency-inclusive script from the **locked disko module evaluated with the host track**. Building/reading it does not run it. Inspect its create/destroy/mount commands and every referenced device. Do not reuse a plan across input/configuration changes or assume a by-id path still names the same physical drive in a rescue environment. If moving the plan to another machine, copy its **whole Nix closure**, not just script text.

### Explicit execution boundary — operator only

After authorized maintenance, backups, a rescue console and final target-local device verification, the generated script can be run **on the intended target's installer**, never on the administration machine:

```sh
sudo ./result-disko-bastion
```

That command is **destructive**; no recipe invokes it. The script contains its combined disko operation; it is not the disko CLI and does not take `--mode` arguments. For reference, upstream CLI calls use `--mode destroy,format,mount`; prefer the repository-built script so neither its module nor tooling floats to upstream HEAD.

Verify `findmnt -R /mnt`, especially `/mnt`, `/mnt/nix`, `/mnt/persist`, `/mnt/boot`. The root must be tmpfs, not a directory on an unintended filesystem. Before installing/rebooting:

- Seed `/mnt/persist/etc/machine-id` from the existing installation **when migrating**, preserving uniqueness. Never copy another host's identity. A new machine can generate a new identity; verify that it lands in persistence.
- Migrate existing SSH host key **pairs** to `/mnt/persist/etc/ssh/` with correct root ownership and private-key permissions; otherwise clients will see changed identity. For new keys, verify the new fingerprints out of band.
- Migrate user/service data into the matching persistent backing paths with correct ownership; back up first. Stage runtime password hashes/other required secrets securely.
- Ensure `/mnt/nix` really is the persistent subvolume; do not try to persist `/nix` through impermanence or install the store into ephemeral root.

From the reviewed repository on the installer, a standard NixOS install is then:

```sh
sudo nixos-install --no-root-passwd --flake .#bastion
```

Do not use `--no-root-passwd` unless the declared admin credentials have actually been provisioned. Review installation logs and backing state **before reboot**. Reboot only with a working recovery console. Hardware-dependent boot, encrypted layouts, provider installs, and migration must be tested for the actual machine; they are not certified by evaluation fixtures.

### First boot acceptance

1. Verify `/` is tmpfs and `/persist`, `/nix`, `/boot` are the intended filesystems (`findmnt`). Confirm persistent mounts precede impermanence services and no mount is silently missing.
2. Confirm machine ID and SSH fingerprints match the intended identity. Test admin login and elevation from a second session without closing the console.
3. On a test path only, confirm an ephemeral marker disappears after a controlled reboot and a declared persisted marker survives. Verify user ownership, saves/documents, network profiles, journal retention and service state. On servers confirm journal entries actually reach `/persist/var/log/journal` after flushing and survive reboot; a successful journald service start alone is not sufficient.
4. Confirm actual UEFI NVRAM entry or fallback boot behavior (or BIOS GRUB), bootloader entries and an older known-good generation are available. Never count deployment magic rollback as a boot or database rollback.
5. For `bastion`, verify no data storage was touched. Do not start future NAS services unless the real data mount is present; use service mount dependencies (`RequiresMountsFor`, conditions) to avoid writing into ephemeral fallback directories.
6. Record the acceptance test and backups/restore procedure before considering the host operational.
