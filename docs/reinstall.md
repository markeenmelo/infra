# Fresh-install preparation — Bastion → Racknerd → ThinkPad

Date: **2026-09-12**. Starting point: clean `redeploy` at `40ff4881552838b5e02dc57a58cf9b0a3f42f375`.

**Updated execution scope:** after planning `7e9bf55` and implementation `a819153`, the operator explicitly requested full validation and **Bastion-only NVMe installation plus two-boot acceptance**. [Authoritative dated status](hosts.md#current-status) records its completed pre-install reviews and remaining validation/runtime gates; Racknerd/ThinkPad stay unready and untouched. Each host composes its own `disko.nix`; no old/new storage framework remains. Bastion uses shared agents, tmux and requested devenv with its existing private `marcos` home, not a new role. [ADR 0003](adr/0003-storage-and-impermanence.md) governs storage. Never activate these fresh layouts over old mounted disks, and do not broaden the [runbook](bootstrap.md#storage-and-installation) beyond the current task authorization.

## Scope and evidence

- Confirmed order: **Bastion → Racknerd → ThinkPad**. ThinkPad stays usable until both servers are accepted and Bastion independently provides the repository, tools and reviewed credentials needed for the final reinstall. Bastion now has verified live-USB preflight; no Racknerd/ThinkPad operation is authorized by it.
- The operator declines a ThinkPad data backup, stating nothing important needs retaining, and reports no Bastion NVMe backup. Record these as choices, **not verified recovery**. Credentials, the repository/lock and installer access still need independent recovery or an explicitly approved replacement plan. Do not silently reset SSH/SOPS/Tailscale identities along with ordinary OS state.
- Bastion's valuable `tank` is to survive unchanged. The operator now reports independent backup/restore **verified**, separately from the observed healthy mirror; “ZFS will still be there” alone would not establish a backup. No data-disk operation or native-mount conversion can proceed on the strength of this statement.
- Read-only local ThinkPad observation: approximately 38 GiB usable RAM; 48 GiB swap LV, not 40 GB; zero swap used after about one day uptime, about 6.7 GiB RAM used / 32 GiB available. Three `vmstat` samples showed no current swap I/O. This is not peak-workload profiling.
- At the initial planning checkpoint no SSH connection to Bastion was made. Its local saved ED25519 fingerprint is `SHA256:amVoQEwcsPE+i4QDkvt1VK6AFf7vlwMBRCM2Enx2yK8`, different from the dated repository record `SHA256:5io89FRLljarJrjAHPbPo3AV5F7ssL6hJtYo42JxOVQ`. The current live-USB key was subsequently console-verified, enabling strictly pinned access without replacing global known-host entries. A distinct future installed key was generated under explicit authorization; see current status rather than treating either as the old installed identity.
- These Bastion identities originated in the **2026-09-09 inventory** and were re-verified in the authorized 2026-09-12 live-USB inspection: OS whole-disk by-id `nvme-eui.6479a7a2ea200e8e`; separate mirror pool `tank`, GUID `7246454901288299061`, hostId `ebbb349e`; members `ata-ST4000VN006-3CW104_ZW63V4FM-part1` and `ata-TOSHIBA_HDWG440_2270A00MFZ1G-part1`. Recheck serials, topology, properties, health and active consumers before implementation/execution.

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

Implemented directly in `modules/hosts/bastion/disko.nix`, `modules/hosts/racknerd/disko.nix` and `modules/hosts/thinkpad/disko.nix`, each selected by its host. No generic storage module remains. Racknerd proposes BIOS GPT, first 1 MiB EF02, 2 GiB FAT `/boot`, remaining Btrfs `nix`/`persist`, and no swap. Its `fleet.installation.osDevice` stays null: the observed `/dev/vda` bootloader identity is not a formatting target. Bastion's NVMe was freshly verified; ThinkPad's historical identifier still needs fresh review. EFI NVRAM writes are an explicit proposed policy on the UEFI hosts, not fresh boot acceptance.

Each file directly imports upstream disko and the shared Limine boot policy. Sizes, subvolumes and firmware settings are native declarations; there is no generic ESP/home/swap/mode interface. The existing installation metadata has a fresh `storageReviewed` gate, default false, covering serials, layout, boot capacity/firmware, backups and credential/state recovery. Local guards reject public scripts/images while unready or missing requirements, and reject extra disks or redirected OS devices. Non-OS destructive collections remain closed. Both-track fixtures cover the three actual layouts with synthetic identities/reviews, never real installer targets.

The repository no longer describes today's bootable ThinkPad storage. Its running generation remains intact, but `ready`, `build`, `disk-plan` and deployment stay blocked for this fresh candidate. Keep independent access to the old generation/repository revision for recovery. Do not carry old boot/migration approval into fresh review, add fixture hosts to fleet outputs or reuse old filesystem UUIDs.

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

**Recommendation:** use the unchanged legacy map in `modules/hosts/bastion/data.nix` for the NVMe-only reinstall first, then perform an independently reviewed native-mount transition if the smaller Nix surface is still preferred. This separates OS replacement from data-pool changes. Native mounting is a sensible destination, not a drop-in cleanup of today's legacy map.

For that possible transition, the intended namespace would remain:

- `tank/srv` mounted at `/srv`.
- Its six observed children (`containers`, `frigate`, `immich`, `nextcloud`, `nixflix`, `yuvomi`) inheriting the corresponding paths, **only after checking each current local/received property source**. A local `legacy` override will not disappear when the parent changes.
- `tank/offsite-stage` explicitly mounted at `/srv/offsite-stage`: it is not a child of `tank/srv`, so parent inheritance alone cannot place it there.
- Preserve the pool-root dataset's reviewed policy and any intentionally unmounted/backup datasets. `canmount` is **not inherited**; inspect every relevant dataset. Retain datasets, snapshots, quotas, compression, encryption and sharing policy; do not flatten or rename data to match the mount tree.

Simply setting `extraPools` without converting legacy properties imports the pool but does not supply its missing mounts. Conversely, property changes can unmount/remount filesystems and affect shares immediately. No broad recursive property change, import/export, mount, pool upgrade or service stop is part of this proposal. Inventory all descendants/volumes and active writers; capture original property values **and sources** before a separately authorized maintenance transition.

Keep by-id discovery and both force-import flags false. The pinned upstream importer waits for ONLINE, then may attempt a degraded import; that is not equivalent to the historical strict GUID/topology/health importer. Decide explicitly whether degraded data service is permitted before replacing that policy. Named `tank` import is not proof of the expected GUID or member serials. Native NixOS also installs shutdown bookkeeping that sets `nixos:shutdown-time`; do not describe using its ZFS module as an absolute guarantee of zero property writes.

For future applications, require successful import/mount ordering **and verify the exact source dataset at the exact mountpoint before writing**. With native mounts, `RequiresMountsFor` alone may cover only the ancestor filesystem if no dataset mount unit is known yet. A directory existing at `/srv/immich`, or even another filesystem mounted there, is insufficient. Prefer explicit service dependencies and fail-closed mount/source checks; test missing-child behavior. No NAS application is enabled by this storage plan.

Do not add the upstream ZFS mount generator merely because a generic Linux guide recommends it: NixOS at this pin already integrates `zfs-mount.service`. A generator introduces another cache/order lifecycle to validate, particularly with tmpfs `/etc`; it is not needed for the basic native approach. Likewise do not introduce a cache-only pool discovery dependency on ephemeral root.

### Simple ongoing ZFS management

Yes: after a reviewed native-mount conversion, `data.nix` can retain only hostId/ZFS support, `boot.zfs.extraPools = [ "tank" ];`, safe import policy, scrub and snapshot scheduling. The pool retains its datasets, mountpoints and properties; Nix need not recreate them. The current file move **does not** convert properties or remove legacy mounts.

The operator selected **standard native snapshots with property-controlled opt-in**, keeping legacy mounts. `data.nix` now enables `services.zfs.autoSnapshot` in the unactivated candidate: retain **4 fifteen-minute, 24 hourly, 7 daily, 4 weekly and 12 monthly** snapshots per opted-in dataset. Existing monthly scrub is explicitly scoped to `tank`; its native six-hour random delay remains. No additional snapshot framework or property-mutating activation hook is introduced.

At this pin snapshotting uses **zfstools**, whose datasets opt in via `com.sun:auto-snapshot=true`, with per-interval overrides available. No on-pool property is changed or assumed known. Enabling the service alone may take no snapshots, or include previously opted-in datasets beyond this mount map; inspect effective inherited/local/received settings before activation. Review free space, existing snapshot naming/holds and automatic pruning. Do not blanket-opt in high-churn recordings or offsite staging. Snapshots retain old blocks and rotation deletes managed snapshots; neither snapshots nor scrub replace an independently restorable backup. Bastion's pre-install NAS review is now complete: 114 snapshots, one held, no native opt-ins or managed snapshot names, and reviewed dataset capacity. First-boot mounts/timers and native shutdown timestamp bookkeeping are separately authorized. No manual snapshot/scrub job, mountpoint/selection-property change, replication, expansion or upgrade is authorized.

## Bastion's temporary administration workspace

Bastion's `host.nix` composes shared `modules/agents.nix` plus tmux and the requested native devenv package; agents supplies Git/gh and the existing Pi extension dependencies/configuration. It uses **Pi 0.75.4 / RTK 0.41.0** from its own stable packages, not backports or a second package set. No Herdr, editor, native-devenv module addition, HM bridge, extra trusted user, agent forwarding, new account or operator abstraction. The normal `marcos` home is persisted on the **OS** `/persist` with owner `marcos` and mode `0700`; this covers checkouts, Pi state/auth and future privately prepared SSH material. It does not copy data, sign in, or establish credential readiness. Existing backing permissions must be reviewed, not assumed repaired by declaration; native non-forcing links retain public Pi configuration while credentials and sessions remain private mutable state.

Before wiping ThinkPad, prove Bastion can work **without it**: log in with the existing account, use Pi with the intended provider and test its npm extensions/older-runtime limitations, reopen the repository/session after reboot, bootstrap this checkout's required CLI with `nix run --no-update-lock-file .#devenv -- shell`, and, when explicitly authorized, run full validation plus ThinkPad readiness/build after its fresh commissioning prerequisites are satisfied. Review private SSH/SOPS recovery and the intended installer/deployment route separately; package availability does not enroll credentials. ThinkPad remains local-only in deploy-rs until an explicit later remote-deployment decision. Building a target is not authorization to activate it.

For cleanup after ThinkPad acceptance, remove Bastion's temporary agents/package/home selection and Bastion-specific checks/inventory entries; retain the shared agent policy/tests still used by ThinkPad. First decide what home state to retain or privately migrate. Removing an impermanence declaration does not erase old backing data; deleting that data is a separate authorized operation.

## Bastion execution gates and sequence

1. **Identify:** resolve SSH-key discrepancy, confirm local/rescue console, and gather fresh read-only OS/data inventory through verified access. Check mounted datasets/property sources, actual import units, writers, free space and current health. An ONLINE mirror/previous scrub is not a restore test.
2. **Recover:** record the OS no-backup choice distinctly from required NAS backup/restore review. Establish independent admin/SSH/SOPS recovery; Bastion now has its distinct recovered identity, shared-password membership and actual early-delivery rehearsal; installed acceptance is still required. New/replaced identities and ciphertext recipient changes need their own approval and private handling. Preserve or deliberately replace host identities; never copy another machine's keys.
3. **Implement and validate locally:** amend the storage ADR/runbook and capability/tests together; retain independent track/readiness inventories. Run native formatting and the canonical full gate for the coherent candidate, then required real readiness/build checks. Inspect generated boot/initrd/storage outputs without executing them. Only reviewed Bastion currently exposes a script; inspect the exact built artifact before any execution.
4. **Review exact installer plan:** compare every destructive command and whole-disk reference against fresh target-local serials. Verify the rescue image supports the selected ZFS/kernel combination. Keep `tank` and its data members completely outside disko; arrange physical isolation during NVMe provisioning wherever possible. Disconnect/export/shutdown are later authorized maintenance operations, not actions to take now.
5. **Authorize separately:** only after the identity, recovery and storage-boundary reviews, request approval for the exact NVMe wipe/format/install and any shutdown/reboot. Reformatting removes old NVMe root subvolumes and boot generations; Nix/deploy rollback cannot restore them. Do not wipe a running mounted OS from an ordinary SSH session.
6. **Install/accept in controlled stages:** OS-only provisioning with the reviewed physical boundary (isolate data disks where practicable), secure identity preparation and console first-boot verification. In the currently authorized Bastion sequence, the verified SATA pool stays exported/unmounted during NVMe-only provisioning and is imported/mounted normally only on the authorized fresh boot. Required legacy mounts may prevent normal boot while the data disks are absent, so design that OS-only acceptance stage explicitly rather than casually adding `nofail`. Verify GUID/member identities, exact dataset mounts, no unexpected shares/writers, credentials, network and two-boot persistence before NAS service use. Native mount conversion, if selected, is a later maintenance stage.
7. **Continue fleet:** only after Bastion acceptance, scope and complete Racknerd's provider-console/no-by-id/BIOS path. Reinstall ThinkPad **last**, after both servers are accepted and Bastion's independent workspace/recovery checks above pass. Wiping the machine running the agent removes its local checkout and recovery generations.

## Validation evidence

The operator resumed full validation; implementation baseline `a819153` passed all 23 checks. The later credential/review/agent changes require their own final full gate and Bastion ready/build. Focused shared-agent checks already pass on both native runtimes, with explicit legacy limitations, and ThinkPad's Pi settings/HM activation derivation stayed unchanged. [Validation records](validation.md) distinguish this from older failed/interrupted runs and from the separately authorized real preflight operations. None of these checks is installed boot or administration-workspace acceptance.
