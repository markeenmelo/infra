# Existing host inventory and baseline transition

Read-only discovery: **2026-09-09 UTC**. All four machines were already installed. No disk script, mount, partition/format/repair, pool import/export, activation, installation or reboot was executed. SSH used existing known-host entries with strict checking and no automatic host-key updates. No private keys, password hashes, VPN state or Wi-Fi secrets were collected.

## Scope and chosen policy

- Headless NixOS with console/emergency recovery, key-only SSH, `marcos` administration with **password-based sudo**, firewall, time synchronization and explicit persistence. Normal account shells default to Bash; existing home contents remain intact. No passwordless sudo or blanket Nix trust.
- Limine on all four; tmpfs `/`, keeping existing durable filesystems. Thinkpad retains its encrypted LUKS/LVM stack and swap. No old Btrfs root-deletion hook is copied; existing root subvolumes remain on disk for recovery.
- Server nftables, conservative kernel hardening and bounded persistent journals. Racknerd additionally gets a journal-backed fail2ban SSH jail with persistent ban database. TCP 22 only; no HTTP(S), shares, reverse proxy or other public application yet.
- Laptop NetworkManager, UPower and power-profiles-daemon (not TLP/auto-cpufreq). Thinkpad also gets Intel thermald, Wi-Fi power saving, and Bolt with its existing authorization state. No blanket Thunderbolt authorization, eGPU driver guess, desktop, Steam, 32-bit gaming stack or performance tuning. These are headless foundations, **not tested gaming configurations**. No charge thresholds are changed.
- **No VPN/Tailscale**, per user decision. Previously persisted VPN/service state is left on backing storage, not deleted; do not treat service removal as key revocation.
- Deploy-rs intent: racknerd, bastion and dino, using `marcos`, root activation and interactive sudo. Thinkpad stays local-only. Closure transport/trust remains unresolved rather than granting root-equivalent Nix access automatically.
- Every host remains **`ready = false`**. This is a configuration/transition plan, not permission to activate it. `nixosConfigurations` and `deploy.nodes` remain empty until real review is complete.

## Storage representation

`existing-storage` uses the locked disko `nodev` type to derive runtime filesystems for existing devices. Despite its name, that type accepts a device and filesystem options and performs no filesystem creation. Disk/GPT/LVM-create/ZFS-create collections are closed and all `system.build` disko script/image/installation-test aliases are rejected, **even after readiness**. `just disk-plan HOST` refuses existing installations. This is deliberately **not** a full install/reformat layout.

Thinkpad's existing LUKS unlock and LVM activation are ordinary NixOS initrd configuration, not disko format instructions. Bastion's existing ZFS legacy mounts are ordinary NixOS `fileSystems`, outside disko. Runtime activation can still change boot files and a later boot mounts these declarations; configuration evaluation is not a migration rehearsal.

The old `os-disk` capability and its synthetic UEFI/BIOS/ESP rejection tests remain for a separately authorized **fresh installation**. None of these four hosts compose it. Never replace `existing-storage` with it to get an installation script.

Inspect the exact configuration, without touching devices:

```sh
just inventory
nix eval --json .#fleet.bastion.filesystems | jq .
nix eval --json .#fleet.thinkpad.persistence | jq .
nix eval --json .#deploymentPlan | jq .
```

## Observed machines

### thinkpad — this machine

- Lenovo ThinkPad T14 Gen 3, model 21AH00BNUS; Intel i7-1270P, ~38 GiB usable RAM, Intel i915 graphics (`8086:46a6`). Thunderbolt controllers present with `user` authorization security; eGPU disconnected at discovery. Previous configuration mentions an RTX 3070, but that is **not live verification** and no driver is carried over.
- UEFI, Limine, Secure Boot variable off. Existing source uses NVRAM writes, preserved as target policy; boot/recovery review remains false.
- Micron 512 GB NVMe, by-id `nvme-eui.00a075013a594e93`. ESP UUID `E0BE-02B0`, 4 GiB, ~119 MiB used at discovery.
- LUKS UUID `072d4bf0-1930-4203-a5ec-1430e2e67c71`, mapper `crypted`, VG `vg`. Btrfs LV `/dev/mapper/vg-system`, filesystem UUID `ed7306e0-58eb-4d13-891d-0cf3cd0fa017`; existing subvolumes `root`, `nix`, `persist`, `home`. Retain the latter three; target root is tmpfs. Preserve `nodiscard` mount policy and the existing discard-capable LUKS mapping; no new scheduled trim job.
- Existing 48 GiB swap LV, UUID `df87ed65-251d-4e5a-8451-f7df56f2819c`; resume device `/dev/vg/swap` retained. Hibernation with this new initrd/root is **not tested**.
- `marcos` UID 1000. NetworkManager Wi-Fi/Ethernet; preserve existing connection profiles, not a hardcoded lease address.
- `stateVersion = "26.05"` from prior installation source. Live version `26.11.20260905.c043004`; the target uses this repository's locked unstable input instead.
- Local stdout-only hardware generator could not inspect Btrfs without privilege. Initrd facts use observed NVMe/USB/Thunderbolt devices and supporting previous source; `hardwareReviewed` intentionally remains false until the privileged scan/initrd review is complete.

### racknerd — `72.11.150.242`

- KVM, five vCPUs, ~5.8 GiB RAM; BIOS boot. Stdout-only hardware scan adapted with the target Nixpkgs QEMU guest profile.
- Single 100 GiB VirtIO `/dev/vda`, no serial/whole-disk by-id. BIOS metadata partition 1; separate 2 GiB FAT `/boot`, UUID `2FE0-AD99`. Limine BIOS target `/dev/vda`, `partitionIndex = 1`; **verify again before any bootloader activation**.
- Btrfs UUID `0ccb8eeb-7ca2-4ba9-871b-e621a921ee49`, subvolumes `root`, `nix`, `persist`. No swap observed/added. Target root tmpfs; `/nix` and `/persist` kept.
- Networkd DHCPv4, MAC `00:16:3c:ec:fa:6f`; lease was `72.11.150.242/24`, gateway `.1`, DNS obtained via DHCP, RA off and IPv6 link-local retained. Configuration preserves DHCP rather than pinning the lease. Provider console/recovery remains unverified.
- Existing account access is **root-only key SSH**. Non-root login does not exist yet. Never switch this baseline through that root-only session without a separately approved staged transition.
- `stateVersion = "26.05"` from prior source; running stable revision `c257840`, not the repository's target revision.

### bastion — `192.168.2.2`

- UGREEN DXP4800 Plus, Intel Pentium Gold 8505, ~62 GiB RAM; UEFI Limine. Target hardware scan adapted; retain existing NVRAM policy pending boot review.
- OS NVMe: 128 GB, by-id `nvme-eui.6479a7a2ea200e8e`. ESP UUID `418B-E89E`, 1 GiB (~126 MiB used). Btrfs UUID `e56256b8-c591-497b-ad32-d4040bbb83be`, subvolumes `root`, `nix`, `persist`. `/persist` **stays on NVMe**.
- Data pool `tank`, GUID `7246454901288299061`, existing two-disk mirror:
  - `ata-ST4000VN006-3CW104_ZW63V4FM-part1`
  - `ata-TOSHIBA_HDWG440_2270A00MFZ1G-part1`
- Pool ONLINE, ~1.66 TiB allocated, zero reported data errors; last scrub 2026-08-31 repaired 0 B. Compatibility property `openzfs-2.4` observed, not set/upgraded by this repository. Health and a mirror do **not** establish backups or a verified restore.
- Retain hostId `ebbb349e` and the eight observed legacy mounts: `/srv`, `/srv/{containers,frigate,immich,nextcloud,nixflix,yuvomi,offsite-stage}`. All use matching `tank/srv/...` datasets except `/srv/offsite-stage` → `tank/offsite-stage`. No ZFS root, new datasets, properties, encryption, shares or migration. Preserve the prior monthly scrub schedule for `tank` only.
- The previous source has a custom strict GUID/topology/health importer. The candidate uses upstream named import with **both force-import flags false**; upstream may accept a degraded pool after waiting. These policies are not equivalent. Review identity, degraded-pool handling, mount failure behavior and restore before setting `fleet.nas.storageReviewed`. A future service must depend on its exact data mount, never fall back to an ordinary `/srv` directory.
- Networkd DHCPv4 on MAC `6c:1f:f7:56:0a:10`; observed lease `192.168.2.2/24` and gateway/DNS `192.168.2.1`, IPv6 RA/link-local disabled on this uplink. Second NIC remains unconfigured.
- Root-only key SSH; same staged non-root transition as racknerd. `stateVersion = "26.05"` from prior source; running stable revision `c257840`.

### dino — `192.168.20.2`

- Dell Inspiron 14 7425 2-in-1, AMD Ryzen 7 5825U, ~14 GiB usable RAM, amdgpu (`1002:15e7`), Intel Wi-Fi (`8086:2725`). Stdout-only privileged hardware scan adapted.
- Already uses 2 GiB tmpfs `/` and ~50%-RAM zram swap; retained. No new hibernation or disk swap.
- SK hynix BC711 512 GB NVMe; Btrfs UUID `a0082a54-1183-461f-a113-3ef1dd7aa396` with `home`, `nix`, `persist` mounts retained. About 271 GiB used; home data is not disposable.
- UEFI Limine, ESP UUID `75D1-3D1A`: **4 GiB partition but ~1 GiB FAT filesystem**, with numerous `FSCK*.REC` fragments. No relevant current-boot kernel messages were returned, which does not clear historical filesystem concerns. No fsck, repair, mount or resize was run. Back up boot contents, verify firmware/Secure Boot/NVRAM policy and filesystem health/capacity offline under separate authorization. Leave `efiCanTouchVariables = null` and `bootReviewed = false`.
- `marcos` UID 1000 and `ian` UID 1001, both have password credentials; preserve both users and `/home`, with only marcos in wheel. Noninteractive sudo was available to marcos at discovery, but the requested **target policy requires a password**.
- NetworkManager Wi-Fi, observed lease `192.168.20.2/24`, gateway/DNS `192.168.20.1`; no hardcoded lease configuration. Deploy-rs eligible after commissioning, but may be offline or suspended.
- **Original stateVersion unknown**; running `26.11pre-git` is not evidence. Keep null until recovered from the original configuration/history or confirmed by the operator.

## Access and state migration checklist — no execution authorized

1. Preserve independent console/rescue access, old boot generations, backups and an actually tested restore. `bootReviewed`, `migrationReviewed`, network/user/provider/NAS flags and `ready` are real review records, not check bypasses.
2. Before removing root SSH on servers, separately provision and test `marcos` plus the chosen public key and password sudo while old access is still available. Do not relax the target's root-login restriction or disable deploy-rs rollback. A separate, authorized compatibility step on the old configuration is needed; this candidate is not that step.
3. Reused operator key fingerprint: `SHA256:mZ36DV6PDIt0lmhfqrO9qKKxQSlmQ7iMiH1NNYWvDRI`. Verified existing server/dino host fingerprints at connection:
   - racknerd: `SHA256:z/SmBv5vFpmgQ6GKvkCVuTm/MoWQdJz0LOOEt2IMECQ`
   - bastion: `SHA256:5io89FRLljarJrjAHPbPo3AV5F7ssL6hJtYo42JxOVQ`
   - dino: `SHA256:YowLGcS8GruKJ5rUJE45rcCMsjAn6JWgETwIDeIkpYI`
4. The desired runtime password files are `/persist/secrets/marcos-password-hash` on each host and `/persist/secrets/ian-password-hash` on dino. These paths are **new delivery contracts, not files we verified or created**. Provision per-host credentials securely, root-owned mode `0600`, parent `0700`; preserve intended existing passwords where appropriate. No secret backend is implemented and old sops deployment is not imported. Never copy hashes through Git, a Nix expression, store input or tool log.
5. Existing SSH host keys live in `/persist/etc/ssh`. The baseline's impermanence declarations expose those same backing key files at `/etc/ssh`; verify fingerprints and modes without rotating keys. Audit machine ID, random seed, NixOS allocation state, timers/time sync, NetworkManager state, Bolt state, power profile state, server journal and fail2ban database. Verify `/persist` parent ownership/modes; impermanence can propagate backing-parent modes onto ephemeral `/etc` and `/var`. Do not persist `/etc` or `/var` wholesale.
6. Laptops already mount `/home` separately; never copy it to `/persist/home` or also bind it through impermanence. Retain ownership/UIDs. Old user-managed dotfiles/Home Manager links may reference removed desktop packages; audit these before login acceptance. Disabling GUI/game packages does not remove their home data.
7. Both laptops currently run a NetworkManager file-secret agent from the old configuration. Preserving connection-profile files alone does **not** prove Wi-Fi credentials will work without that agent/old secret delivery. Securely migrate/verify the necessary runtime connection credentials without exposing them; test networking before acknowledging `networkReviewed`. Remove Tailscale only after verifying required routing and SSH reachability without it, with console access retained. Current successful SSH is not proof of post-removal connectivity. Preserve old `/persist/var/lib/tailscale` backing state without using/logging it; VPN enrollment/ACL design is later work. Likewise unused prior service data remains intact.
8. Choose closure transport separately: signed closures require provisioned target public trust and an operator key outside Git; `trusted-user` would explicitly grant root-equivalent Nix access. Password sudo alone does not establish closure trust. Interactive deploy-rs sessions must be able to prompt.
9. After resolving genuine blockers: `just fmt`, `just check`, then approve readiness and run `just ready HOST` / `just build HOST`. Those commands do not authorize deployment. Review the built initrd, bootloader and persistence transition before any separately authorized activation/reboot. Perform two-boot persistence, SSH, network, boot-generation and ZFS acceptance with a console. None of that runtime acceptance has been performed here.
