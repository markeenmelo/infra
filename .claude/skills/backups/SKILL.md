---
name: backups
description: "bastion's backups: the nightly restic runs to the USB disk and to pCloud, the ZFS and /persist snapshots it reads from, the PostgreSQL dumps and the monthly restore drill. Use before touching modules/backups.nix or the /mnt/backup mount, adding a dataset that holds data worth keeping, restoring anything, or rotating the restic password."
---

# Backups

[backups.nix](../../../modules/backups.nix) backs bastion up to the USB disk at `/mnt/backup`
(ext4, automounted, [data.nix](../../../modules/hosts/bastion/data.nix)) every night at 02:30.
Before each run it dumps every database of bastion's PostgreSQL to
`/srv/backups/postgresql` (the arr databases live in the downloads guest, which dumps them at 01:15
into `/srv/backups/downloads`, [services: arr](../services/arr.md)), snapshots `/srv` and each backup root as `@restic-usb`, and takes a
read-only btrfs snapshot of `/persist`; at 04:00, after the USB run, the `pcloud` job does the
same under `@restic-pcloud` into `pcloud:bastion/restic`, the repository the old generation
filled. restic reads those snapshots, so each dataset is
consistent and no app stops. The dumps finish before the snapshots, so an app writing in between
(an Immich upload) can leave its database and files a moment apart; Immich's own repair jobs
reconcile that after a restore. A failed dump keeps the previous one as `DB.prev.sql.gz`, which
the drill then tests. The roots are `/srv`,
Immich, OpenCloud and the arr state; an assertion fails the build when
Immich's or OpenCloud's data falls outside them. Media, Frigate recordings, PostgreSQL's live files,
Immich's thumbnails and transcodes, the journal and `/var/log`, caches and every identity (host and SSH keys,
`/persist/zfs`, sbctl, tailscale, machine-id) stay out. Each repository keeps 7 daily, 4 weekly and 6
monthly snapshots, grouped by host only, so snapshots from older backup paths age out too. Each pCloud run checks a random 1% of its data, which bounds the download. On
the 15th the drill reads a twelfth of the USB repository, a different twelfth
each month, and tests that every dump listed in `fleet.databaseDumps` (bastion's PostgreSQL and the downloads guest's arr databases) in the latest snapshot decompresses and ends with pg_dump's completion line.

The repositories open with `backups/restic-password`. bastion reaches pCloud directly with
`backups/rclone-pcloud`, a full rclone config, so a compromised bastion can delete the off-site
copies too; the operator accepted that over an append-only proxy on another host. Restore with
`restic -r /mnt/backup/restic snapshots` and `restic restore`, run as root on bastion; for
pCloud, `-r rclone:pcloud:bastion/restic` with `RCLONE_CONFIG` pointing at that secret.
