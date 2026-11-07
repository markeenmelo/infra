---
name: backups
description: "bastion's backups: the nightly restic run to the USB disk, the ZFS and /persist snapshots it reads from, the PostgreSQL dumps, the monthly restore drill, and the append-only restic server that takes the ThinkPad's home backups with its forged-date guard. Use before touching modules/backups.nix or the /mnt/backup mount, adding a dataset that holds data worth keeping, restoring anything, or rotating the restic password."
---

# Backups

[backups.nix](../../../modules/backups.nix) backs bastion up to the USB disk at `/mnt/backup`
(ext4, automounted, [data.nix](../../../modules/hosts/bastion/data.nix)) every night at 02:30.
Before each run it dumps every PostgreSQL database except the arr log ones to
`/srv/backups/postgresql`, snapshots `/srv` and each backup root as `@restic-usb`, and takes a
read-only btrfs snapshot of `/persist`; restic reads those snapshots, so each dataset is
consistent and no app stops. The dumps finish before the snapshots, so an app writing in between
(an Immich upload) can leave its database and files a moment apart; Immich's own repair jobs
reconcile that after a restore. A failed dump keeps the previous one as `DB.prev.sql.gz`, which
the drill then tests. The roots are `/srv`,
Immich, OpenCloud, Nextcloud until its dataset is destroyed (previews left out), the arr state and
the ThinkPad's repository; an assertion fails the build when
Immich's or OpenCloud's data falls outside them. Media, Frigate recordings, PostgreSQL's live files,
Immich's thumbnails and transcodes, logs, caches and every identity (host and SSH keys,
`/persist/zfs`, sbctl, tailscale, machine-id) stay out. Retention is 7 daily, 4 weekly and 6
monthly snapshots. On the 15th the drill reads a twelfth of the repository, a different twelfth
each month, and tests that every dump in the latest snapshot decompresses.

The ThinkPad backs its home up to `backup-thinkpad`, an append-only `rclone serve restic` on
bastion's tailnet address, port 8010, reachable from the ThinkPad's address only (the tailnet
grant in the [OpenTofu project](../opentofu/SKILL.md) and an nftables rule); it has no login, so
an nftables output rule also refuses connections to it from bastion's own processes. Append-only means a
compromised laptop cannot delete its history. On Sundays the retention job stops the server,
refuses to prune if any snapshot claims a date more than an hour ahead or was uploaded more than
8 days after its claimed date, then keeps everything from the last 14 days, so a forged snapshot
cannot displace a genuine recent one, plus 7 daily, 5 weekly and 12 monthly, and checks 5% of the
data. The repository is also a backup root, so it reaches the USB disk too.

The household repository opens with `backups/restic-password`, the ThinkPad's with
`backups/thinkpad-password` ([secrets skill](../secrets/SKILL.md)), so the household key can
change without the laptop ever learning it. Restore
with `restic -r /mnt/backup/restic snapshots` and `restic restore`, run as root on bastion.
Off-site copies to pCloud through racknerd and the backup metrics are not ported yet.
