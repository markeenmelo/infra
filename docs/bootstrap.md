# Commissioning a host

This runbook covers the **fresh per-host reinstall candidates**. **It is not authorization to touch disks or deploy.** Both servers have completed fresh pre-install fact review; ThinkPad remains unready. [Current status](hosts.md#current-status) distinguishes authorization, validation and actual installation/boot acceptance. Never activate these plain layouts over the old mounted disks. Follow [the ordered reinstall/recovery plan](reinstall.md) first, then work from a rescue environment/local console only with separate boot/storage/network authorization and verified recovery. Bastion's install/two boots are accepted; the operator subsequently authorized Racknerd's exact single-disk reset, fresh identities, signed trust and two boots. Neither task authorizes ThinkPad operations or makes this runbook executable permission.

## 1. Gather facts before editing

For each host, record outside public Git if sensitive:

- Original installation `system.stateVersion` (or deliberate initial release for a new installation).
- Actual hardware-generated configuration, firmware boot mode, required initrd modules, CPU/graphics/firmware decisions. Do not infer these from “ThinkPad”, “VPS” or a hostname.
- Verified **whole OS disk** by-id identifier, model/serial/capacity and an explicit list of valuable data disks that are **not** that disk. Stable by-id may not be available on some providers: do not invent one; adapt the storage capability after obtaining an equally stable, independently verified identifier.
- Networking, provider requirements, IPv4/IPv6/DNS/routing, public/private interface firewall policy, SSH reachability and rescue-console access. The base deliberately disables implicit DHCP; supply the actual policy. Workstations use NetworkManager but still need their network policy reviewed.
- Real administration and interactive account names, public-key fingerprints, privilege policy, password-hash provisioning, closure trust.
- Intended session/software scope. ThinkPad explicitly selects the [new Hyprland/Noctalia desktop](desktop.md); all other hosts remain headless. GPU gaming stack, launchers/licensing and controllers are deferred, not acknowledged as tested. No Steam, Gamescope, NVIDIA driver or performance tweak is selected implicitly.
- For `bastion`: independent NAS data inventory, existing filesystem/topology facts, restore plan and future service mount requirements. A functioning OS must not imply approval to alter NAS storage.

On the **target**, read-only inventory commands include:

```sh
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL,UUID
findmnt
ls -l /dev/disk/by-id/
test -d /sys/firmware/efi && echo UEFI || echo 'Verify BIOS/provider boot mode'
```

Do not publish captured output indiscriminately. Before a new install, `nixos-generate-config --no-filesystems --root /mnt` can generate hardware information **after mounting the intended target**; it writes configuration files but does not partition disks. Review it outside `modules/` first. During existing-host discovery, only `--show-hardware-config --no-filesystems` (stdout-only) was used; it wrote no configuration files. See [discovery limitations](hosts.md).

## 2. Add facts as top-level modules

Create files naming their concern, e.g. `modules/hardware/thinkpad.nix`, `modules/hosts/thinkpad/disko.nix`, `modules/access/thinkpad.nix`. Paths are organizational, not import rules. Each file contributes to the same deferred `fleet.hosts.thinkpad.module` value. Do not place a raw lower-level generated `.nix` file in the repository and import it from a host; adapt its reviewed contents into the deferred value.

For an **uncommissioned fresh candidate**, the installation metadata shape is below. Nulls/false reviews intentionally block commissioning and scripts. Edit the existing facts rather than add conflicting definitions; native partitions and firmware settings belong directly in the host's `disko.nix`.

```nix
{
  fleet.hosts.thinkpad.module = {
    fleet.installation = {
      stateVersion = null;
      hardwareReviewed = false;
      networkReviewed = false;
      osDevice = null;
      storageReviewed = false;
    };
  };
}
```

Replace `null` only with verified choices. Add actual kernel/initrd/network settings in the appropriate deferred module. Do not import old scanner filesystem UUIDs, encryption or swap into a freshly formatted layout. The running installation and its recovery generation must remain untouched until the authorized cutover. Generated `nixpkgs.hostPlatform` should agree with required host metadata. Keep `stateVersion` in `fleet.installation.stateVersion`, which sets the NixOS option; do not give it a second, conflicting direct definition.

No one-time value comes from the dev shell's Nixpkgs, another host, or a hardware scan of the administration machine. User preference settings (timezone, locale, keymap, desktop) should also be deliberate rather than inferred.

## Access and secrets

`modules/access.nix` defines an immutable, initially locked account policy:

1. Supply `fleet.access.admin` and **public** `fleet.access.authorizedKeys`; verify with the owner's fingerprint. Root login and SSH passwords remain disabled.
2. For password-based console/sudo, map each account in `fleet.access.passwordSecrets` to a declared SOPS secret with `neededForUsers = true`. Only encrypted hashes enter Git/the store; the account consumes the secret's early runtime `.path`, root-only mode `0400`. Null or undeclared bindings block commissioning. Separately provision/verify its dedicated identity at the typed string `fleet.secrets.ageKeyFile`, directly on early-mounted `/persist`, and establish protected recovery copies. Acknowledge `identityReviewed` only after actual custody, recipient/permissions and early-decryption verification. See [the secret procedure](../secrets/README.md); pure checks do not decrypt or establish working login.
3. Alternatively, explicitly choose `fleet.access.passwordlessSudo = true`; this grants root-equivalent privilege to that account. Do not enable it merely to pass a check. Desktops need working interactive password/login arrangements even if SSH administration works.
4. Configure actual interactive users through normal NixOS user options in host/user features. Acknowledge `fleet.workstation.usersReviewed` only after accounts/privileges are checked. `/home` persists on workstations. Server home state is ephemeral unless separately declared.
5. Deployment requires metadata `sshUser`, `hostname` and a deliberate `transport`. `sshUser` must name an explicitly configured **non-root** account with public keys; root is rejected even if it has keys because SSH root login is disabled. Keep `deployment.profileUser = "root"` for system activation and verify elevation from the SSH account:
   - `trusted-user`: explicitly adds the SSH account to `nix.settings.trusted-users`. **Nix trust is root-equivalent even when sudo still prompts.**
   - `signed`: provision an operator signing key outside this repository, add its public counterpart to the target's `nix.settings.trusted-public-keys`, and supply `LOCAL_KEY` when deploying. Do not disable signature checking. Verify this path before relying on it remotely.
6. Default escalation is interactive `sudo -u`. For automation use an explicitly reviewed passwordless elevation policy and `interactiveSudo = false`. `doas -u` requires separately configuring doas; selecting a command does not configure authorization. SOPS delivers passwords, not SSH enrollment, sudo authentication or Nix closure trust.

Future service secrets may use the same SOPS capability, with separately researched consumers, permissions, ordering and migration. Keep decrypted values/private identities outside Nix expressions/store inputs; ciphertext and public metadata are the only repository inputs. The selected fresh layouts are plain Btrfs. ThinkPad's new candidate intentionally removes LUKS/LVM, but its running encrypted disk remains intact; do not activate the new settings over it. Fresh storage and swap expose data offline. Formatting/encryption changes still need explicit execution and recovery approval.

## 3. Resolve capability-specific blockers

`devenv tasks run repo:inventory` explains every unresolved field. Hardware/network review, user credentials and provider/NAS review are real barriers, not automatic discovery. `fleet.installation.storageReviewed` separately requires fresh serial/layout/firmware/boot-capacity, backup, credential-recovery and migration review; old-installation acceptance does not satisfy it. Headless workstation use does not require a desktop acknowledgement. ThinkPad's graphical capability requires genuine `fleet.desktop.reviewed` acceptance of login/locking/sleep, portals, audio and the mobile display; follow [its checklist](desktop.md#activation-and-acceptance-checklist). This flag does not certify future eGPU/HDR or gaming behavior.

Supply deployment metadata through `fleet.hosts.<name>.deployment`, independently of the NixOS module. Racknerd and bastion opt in after commissioning; thinkpad remains local-only. Keep `ready = false` during discovery. Once every fact is supplied, inspect `git status --short`, `git diff` and `git diff --cached`. Stage intended new files **individually**, using `git add -- path/to/reviewed-file`, after reviewing each path; never stage the whole `modules` directory or unrelated work. Run `devenv tasks run repo:secret-check` before staging intended ciphertext/public rules. Inspect `git diff --cached` again, then run in the locked shell:

```sh
devenv tasks run repo:fmt
devenv tasks run repo:check-full
nix eval --json .#fleet.thinkpad | jq '{missing,failedAssertions}'
```

An unready host still has its commissioning assertion. Only after resolving all other issues set `fleet.hosts.thinkpad.ready = true` in a commissioning/identity module, then rerun `devenv tasks run repo:check-full` and `devenv shell ready thinkpad`. Merely setting ready with missing fields makes validation fail; it never overrides them. Source-control facts before installing; retain the exact lock file and recovery generation.

## Storage and installation

**All three candidates compose their per-host fresh layouts; both servers now have pre-install commissioning approval, while ThinkPad remains blocked.** Use [hosts.md](hosts.md#current-status) for exact execution scope and results; other candidates and operations remain blocked.

**Everything below the explicit execution boundary is a manual maintenance-window operation. Disko may erase the entire selected disk, including existing partitions and boot entries. It is not a migration tool. Never run it during ordinary deployment.**

Each `modules/hosts/<host>/disko.nix` directly declares its native partitions and boot settings; no generic layout/firmware option interface remains. `fleet.installation.osDevice` is nullable whole-disk metadata; unresolved identity or fresh review blocks public outputs, as does unready status. Fixed FAT boot sizes are Bastion/Racknerd **2G** and ThinkPad **4G**; review kernel/initrd sizes and retained generations before approval. BIOS has a first 1 MiB EF02 embedding partition and no ESP. The proposed native `boot.loader.efi.canTouchEfiVariables = true` on UEFI hosts allows Limine NVRAM writes; review this or deliberately select/test fallback boot. All three use tmpfs `/` and Btrfs `nix`/`persist`; ThinkPad adds `home` and **8G plain swap**, without LUKS/LVM/resume or hibernation. “100%” is the remainder policy, not observed capacity. Racknerd's approved no-serial exception uses canonical `/dev/disk/by-path/pci-0000:00:04.0`; verify VM/attachment identity, capacity and current use before formatting. PCI topology is not an immutable disk serial. Bastion/ThinkPad still require whole-disk by-id identities.

Only `disko.devices.disk.os` is allowed: additional disks or an OS device redirected away from the reviewed fact reject public script/image outputs. Unused `lvm_vg`, `mdadm`, `zpool` and `bcachefs_filesystems` collections are forced empty; foreign contributions cannot expand the generated plan. NAS data disk definitions, multi-device pools, shares and backup jobs are absent. **For `bastion`, disconnect valuable data disks during initial OS provisioning where practicable**, independently compare serials, and have another person review the boundary. If an OS and valuable data share the same disk, **do not use this baseline**; design a migration that preserves data instead.

### Non-destructive planning

After real facts and readiness are approved:

```sh
devenv tasks run repo:check-full
devenv shell ready bastion
nix eval --json .#fleetConfigurations.bastion.config.disko.devices.disk.os.device
nix eval --json .#fleetConfigurations.bastion.config.fileSystems | jq .
devenv shell disk-plan bastion
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
- Migrate user/service data into the matching persistent backing paths with correct ownership; back up first. Provision/verify the dedicated SOPS identity securely under the mounted target's `/mnt/persist/var/lib/sops-nix/`, never in the Nix store; verify encrypted credential delivery before accepting the install.
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
