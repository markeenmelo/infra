# Fresh-install proposal — bastion first

Date: **2026-09-12**. Starting point: clean `redeploy` at `40ff4881552838b5e02dc57a58cf9b0a3f42f375`.

**Planning only.** The operator selected fresh-install planning for Bastion's OS NVMe and ThinkPad, with no ThinkPad LVM, encryption or hibernation. No current host composition, readiness/review flag, credential, lock or disk has changed. [ADR 0005](adr/0005-existing-headless-baseline.md) remains the implemented policy; current hosts still refuse provisioning outputs. This proposal is not permission to execute the [fresh-install runbook](bootstrap.md#storage-and-installation).

## Scope and evidence

- Order: Bastion first. Racknerd remains a later, separately scoped host; no remote access to it or fresh inventory was requested/performed here. ThinkPad stays usable as the administration machine until its later reinstall.
- The operator declines a ThinkPad data backup, stating nothing important needs retaining, and reports no Bastion NVMe backup. Record these as choices, **not verified recovery**. Credentials, the repository/lock and installer access still need independent recovery or an explicitly approved replacement plan. Do not silently reset SSH/SOPS/Tailscale identities along with ordinary OS state.
- Bastion's valuable `tank` is to survive unchanged. Its independent backup/restore status is **unverified**: “ZFS will still be there” does not establish a backup. No data-disk operation or native-mount conversion can proceed on the strength of this statement.
- Read-only local ThinkPad observation: approximately 38 GiB usable RAM; 48 GiB swap LV, not 40 GB; zero swap used after about one day uptime, about 6.7 GiB RAM used / 32 GiB available. Three `vmstat` samples showed no current swap I/O. This is not peak-workload profiling.
- No SSH connection to Bastion was made. Its local saved ED25519 fingerprint is `SHA256:amVoQEwcsPE+i4QDkvt1VK6AFf7vlwMBRCM2Enx2yK8`, different from the dated repository record `SHA256:5io89FRLljarJrjAHPbPo3AV5F7ssL6hJtYo42JxOVQ`. The discrepancy is unexplained. Verify the current key through the console or another independent trusted channel before trusting remote inventory; do not replace known-host entries automatically.
- Bastion identities below are the **2026-09-09 inventory**, not a new observation: OS whole-disk by-id `nvme-eui.6479a7a2ea200e8e`; separate mirror pool `tank`, GUID `7246454901288299061`, hostId `ebbb349e`; members `ata-ST4000VN006-3CW104_ZW63V4FM-part1` and `ata-TOSHIBA_HDWG440_2270A00MFZ1G-part1`. Recheck serials, topology, properties, health and active consumers before implementation/execution.

## Concise OS layout

Retain Btrfs plus tmpfs root and scoped impermanence; removing LVM does not require replacing Btrfs. Proposed sizes are **design recommendations**, not new hardware facts or approved plans.

| Component | Bastion | ThinkPad |
|---|---|---|
| Partition table | GPT on the verified OS NVMe only | GPT on its independently verified NVMe only |
| ESP, vfat `/boot` | Propose 2 GiB; review built Limine/kernel/initrd headroom | Retain the current 4 GiB size; review candidate headroom |
| Disk swap | None initially, matching the existing declaration | Propose 8 GiB plain swap partition, before the remaining-space partition |
| Remaining space | One plain Btrfs filesystem | One plain Btrfs filesystem; no LUKS or LVM |
| Btrfs subvolumes | `nix` → `/nix`, `persist` → `/persist` | Same, plus `home` → `/home` |
| Root | tmpfs, retain the existing size ceiling/persistence policy | Same |
| Bootloader | Limine UEFI | Limine UEFI |
| Data pool | Not an OS filesystem and never a disko creation target | No ZFS proposed |

Use the pinned disko GPT/Btrfs/swap types to derive runtime filesystems; do not duplicate the same fresh layout as `nodev` declarations. Keep `/nix`, `/persist` and ThinkPad `/home` early-mounted. Keep `/home` out of impermanence binds when separately mounted. Compression/noatime policy belongs in a small local subvolume constructor, with deliberate discard policy; no generic layout framework or another package universe is needed.

The existing `os-disk` capability is **not ready to substitute for `existing-storage`**: it currently selects systemd-boot/GRUB, uses `@nix`/`@persist`, and lacks the proposed separate home/swap layout. Update that capability deliberately, share Limine policy with existing installations, and test each selected layout. Never import both storage modes into one host. Keep the closed non-OS destructive collections, confirmed whole-device checks and direct-script rejection tests.

Initially develop the fresh layout as an uncomposed capability with synthetic evaluation-only fixtures. Preserve the current bootable ThinkPad composition during planning. Switching a real host to the new layout later requires a coherent candidate, new installation-specific review and readiness gates; old boot/migration acceptance does not certify a freshly formatted disk. Do not add fixture hosts to fleet/install/deploy outputs or reuse old filesystem UUIDs as new filesystem facts.

## ThinkPad swap decision

**Recommend 8 GiB disk swap for the selected typical-use/no-hibernation policy.** This is an initial buffer, not a proven optimum. Compared with the current 48 GiB LV, it returns **40 GiB** to ordinary storage.

| Keeping 40–48 GiB swap | Benefit / cost |
|---|---|
| Hibernation | Generous disk-backed image headroom, but the operator does not want this feature. RAM-sized swap is not a universal kernel requirement; image size, compression and already-used swap matter. |
| Memory bursts | More room for cold anonymous pages, large builds/VMs and sometimes completion instead of allocation failure. It cannot prevent every OOM or replace physical RAM. |
| Capacity | The current LV reserves about 10% of the nominal 512 GB SSD, whether used or not. |
| Responsiveness | Heavy swapping can prolong severe stalls before workloads fail. Size alone does not force swapping; workload, memory pressure and reclaim policy do. |
| SSD writes | Used disk swap adds I/O and wear; unused allocated swap does not continuously write or wear the SSD. |
| Confidentiality | Once encryption is removed, OS/home/state and disk-swapped memory can be read offline. Login passwords and SOPS ciphertext do not encrypt the disk or protect an on-disk private SOPS identity from physical access. |

A small partition is straightforward and avoids Btrfs swapfile maintenance restrictions, but later resizing is less convenient. An 8 GiB swapfile in its own subvolume is a supported alternative if flexibility matters: disko uses native `btrfs filesystem mkswapfile`; the file must satisfy no-hole/NODATACOW/no-compression and device/profile constraints. The active containing subvolume cannot be snapshotted, and a separate subvolume does not eliminate whole-filesystem balance/scrub restrictions. Do not implement it as a generic compressed file under `/persist` or as a ZFS swapfile.

Zram-only is another reasonable desktop alternative: compressed RAM, no fixed SSD reservation, CPU/compressibility trade-offs and no disk-backed overflow/hibernation guarantee. Defer it initially to keep the chosen policy small; if adopted, explicitly size its logical capacity and priority, rather than confusing it with reserved physical RAM. No measured benefit or mandatory need for zram is established here.

During the **later reinstall candidate**, remove the old LUKS unlock, LVM activation, swap UUID and `/dev/vg/swap` resume binding together. Explicitly disallow hibernation, hybrid sleep and suspend-then-hibernate while preserving ordinary suspend. Without hibernation, a suspended laptop still consumes power and cannot recover an unsaved session after battery exhaustion. Review desktop sleep actions and test suspend after installation; do not merely hide a menu item. None of these removals is safe to activate over today's encrypted disk.

Measure representative concurrent browser/development/build workloads after installation using available memory, swap-in/out rates, memory PSI and OOM events. Revisit 8 → 16 GiB only if sustained evidence warrants it; tune build concurrency before treating extensive disk swapping as a performance solution.

## Does every ZFS dataset need a Nix declaration?

**No, but every dataset currently using `mountpoint=legacy` needs an explicit mount if its contents are to be accessible.** Mounting `tank/srv` does not recursively mount separate child datasets. The existing eight-entry table is a runtime mount map, **not dataset or pool creation**. No need to put existing datasets into disko or recreate/merge them to shorten Nix.

Both models are upstream-supported ([pinned research](research.md#fresh-install-storage-and-zfs-mounting--2026-09-12)):

| Model | What owns mounting | Trade-off |
|---|---|---|
| Legacy, current NixOS approach | ZFS retains `mountpoint=legacy`; Nix `fileSystems` declares the required mounts. NixOS derives the pool import and systemd mount ordering. | Explicit and reproducible in the repo; one compact mount-map entry per mounted dataset. No on-pool property conversion needed. |
| Native ZFS | Absolute/inherited ZFS `mountpoint` properties plus appropriate per-dataset `canmount`; Nix names `tank` in `boot.zfs.extraPools`, retaining hostId/ZFS support/import policy/scrub. | Smaller Nix config, portable mount policy on the pool; properties become managed on-disk state, not wholly reconstructed from Nix. Native mounting can also expose additional eligible datasets outside today's allowlist. |

**Recommendation:** use legacy mounts for the NVMe-only reinstall first, then perform an independently reviewed native-mount transition if the smaller Nix surface is still preferred. This separates OS replacement from data-pool changes. Native mounting is a sensible destination, not a drop-in cleanup of today's legacy map.

For that possible transition, the intended namespace would remain:

- `tank/srv` mounted at `/srv`.
- Its six observed children (`containers`, `frigate`, `immich`, `nextcloud`, `nixflix`, `yuvomi`) inheriting the corresponding paths, **only after checking each current local/received property source**. A local `legacy` override will not disappear when the parent changes.
- `tank/offsite-stage` explicitly mounted at `/srv/offsite-stage`: it is not a child of `tank/srv`, so parent inheritance alone cannot place it there.
- Preserve the pool-root dataset's reviewed policy and any intentionally unmounted/backup datasets. `canmount` is **not inherited**; inspect every relevant dataset. Retain datasets, snapshots, quotas, compression, encryption and sharing policy; do not flatten or rename data to match the mount tree.

Simply setting `extraPools` without converting legacy properties imports the pool but does not supply its missing mounts. Conversely, property changes can unmount/remount filesystems and affect shares immediately. No broad recursive property change, import/export, mount, pool upgrade or service stop is part of this proposal. Inventory all descendants/volumes and active writers; capture original property values **and sources** before a separately authorized maintenance transition.

Keep by-id discovery and both force-import flags false. The pinned upstream importer waits for ONLINE, then may attempt a degraded import; that is not equivalent to the historical strict GUID/topology/health importer. Decide explicitly whether degraded data service is permitted before replacing that policy. Named `tank` import is not proof of the expected GUID or member serials. Native NixOS also installs shutdown bookkeeping that sets `nixos:shutdown-time`; do not describe using its ZFS module as an absolute guarantee of zero property writes.

For future applications, require successful import/mount ordering **and verify the exact source dataset at the exact mountpoint before writing**. With native mounts, `RequiresMountsFor` alone may cover only the ancestor filesystem if no dataset mount unit is known yet. A directory existing at `/srv/immich`, or even another filesystem mounted there, is insufficient. Prefer explicit service dependencies and fail-closed mount/source checks; test missing-child behavior. No NAS application is enabled by this storage plan.

Do not add the upstream ZFS mount generator merely because a generic Linux guide recommends it: NixOS at this pin already integrates `zfs-mount.service`. A generator introduces another cache/order lifecycle to validate, particularly with tmpfs `/etc`; it is not needed for the basic native approach. Likewise do not introduce a cache-only pool discovery dependency on ephemeral root.

## Bastion execution gates and sequence

1. **Identify:** resolve SSH-key discrepancy, confirm local/rescue console, and gather fresh read-only OS/data inventory through verified access. Check mounted datasets/property sources, actual import units, writers, free space and current health. An ONLINE mirror/previous scrub is not a restore test.
2. **Recover:** record the OS no-backup choice distinctly from required NAS backup/restore review. Establish independent admin/SSH/SOPS recovery; Bastion currently has no verified dedicated SOPS identity or shared-password recipient. New/replaced identities and ciphertext recipient changes need their own approval and private handling. Preserve or deliberately replace host identities; never copy another machine's keys.
3. **Implement and validate locally:** amend the storage ADR/runbook and capability/tests together; retain independent track/readiness inventories. Run native formatting and the canonical full gate for the coherent candidate, then required real readiness/build checks. Inspect generated boot/initrd/storage outputs without executing them. No current script output is available to use as an installer plan.
4. **Review exact installer plan:** compare every destructive command and whole-disk reference against fresh target-local serials. Verify the rescue image supports the selected ZFS/kernel combination. Keep `tank` and its data members completely outside disko; arrange physical isolation during NVMe provisioning wherever possible. Disconnect/export/shutdown are later authorized maintenance operations, not actions to take now.
5. **Authorize separately:** only after the identity, recovery and storage-boundary reviews, request approval for the exact NVMe wipe/format/install and any shutdown/reboot. Reformatting removes old NVMe root subvolumes and boot generations; Nix/deploy rollback cannot restore them. Do not wipe a running mounted OS from an ordinary SSH session.
6. **Install/accept in controlled stages:** OS-only provisioning with data disks isolated, secure admin/identity preparation and console first-boot verification; then separately reconnect/import the preserved pool under the reviewed policy. Required legacy mounts may prevent normal boot while the data disks are absent, so design that OS-only acceptance stage explicitly rather than casually adding `nofail`. Verify GUID/member identities, exact dataset mounts, no unexpected shares/writers, credentials, network and two-boot persistence before NAS service use. Native mount conversion, if selected, is a later maintenance stage.
7. **Continue fleet:** only after Bastion acceptance, scope Racknerd's provider-console/no-by-id/BIOS path. Reinstall ThinkPad last, with this repository and independent credentials available elsewhere; wiping the machine running the agent also removes its local checkout and recovery generations.

## Validation of this proposal

Only documentation changes are intended. The existing configuration's canonical preflight was started before possible SSH discovery; its result is recorded in [host status](hosts.md#reinstall-planning--2026-09-12). That gate validates the **unchanged existing-installation code**, not the proposed fresh layout. [Documentation-only checks](validation.md#documentation-only-changes) passed: staged/unstaged whitespace, nine changed relative links/anchors and Bash syntax/ShellCheck for the recorded preflight command (not re-executed). No new fenced executable snippets were added. The new proposal is staged for Git discovery; existing research/status edits remain unstaged, with no commit. No host build, deployment, secret decryption or physical storage acceptance is implied.
