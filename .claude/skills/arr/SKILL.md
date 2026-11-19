---
name: arr
description: "Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd, Seerr, Recyclarr and Decluttarr on bastion through nixflix: their logins and databases, the Proton WireGuard namespace they run in, ProtonVPN port forwarding, the firewall around the namespace, their web UIs on the LAN and the tailnet, the torrent and usenet indexers, the Easynews bridge, the usenet servers, media requests and the quality profile. Use before touching modules/arr.nix, modules/downloads.nix, modules/easynews-indexer.pkg.nix or modules/decluttarr.pkg.nix, changing indexers, servers, quality profiles or download limits, rotating the WireGuard config or a provider credential, or debugging downloads, imports or the VPN."
---

# Arr apps

[arr.nix](../../../modules/arr.nix) runs Sonarr, Radarr, Prowlarr, qBittorrent and SABnzbd from
nixflix inside the `downloads` MicroVM on bastion (below), on the media datasets shared with
Jellyfin ([jellyfin skill](../jellyfin/SKILL.md)), the arr databases in a PostgreSQL of the
guest's own over its socket. The file has two halves: `guest`, what runs in the MicroVM, and
`host`, what bastion keeps (the secrets, Seerr, the exporters, the proxy entries, the firewall).
nixflix wires Prowlarr to Sonarr and Radarr and both to qBittorrent and SABnzbd from the declared
API keys; its setup units apply settings after every start. Their bind address also goes in as an
environment variable, which wins over `config.xml`: the setup units can only reach an app at the
namespace address, so an address carried in an old `config.xml` would keep it unreachable. SABnzbd's config is regenerated from
Nix at each start, so its categories unit reruns with it; its queue and logs live in the state
dataset.

All of them run in nixflix's WireGuard namespace on Proton's config (`arr/proton-wireguard`,
generated with NAT-PMP on), so indexer searches, metadata and downloads leave only through the
tunnel. nixflix confines them together: an app inside cannot reach one outside.
[vpn-watch.nix](../../../modules/vpn-watch.nix) restarts the tunnel when it fails or its handshake
goes stale, and starts the confined apps again each time it comes up. Their web UIs are
`sonarr.`, `radarr.`, `prowlarr.`, `qbittorrent.` and `sabnzbd.DOMAIN` through the LAN proxy, on
the LAN and the tailnet ([proxy skill](../proxy/SKILL.md)); the arr apps and SABnzbd log in as
`marcos` with `arr/password`. The namespace lives inside the guest, and
nixflix's port mappings forward the guest's address to the apps for bastion alone, the one
address the namespace routes back outside the tunnel. On bastion the `arr` nftables table lets
only root and Caddy open new connections to the guest, and Seerr only to Sonarr and Radarr, and
the `exportarr` user (uid 357) only to the three arr apps. One exportarr exporter per app publishes its
health checks (indexers, download clients, root folders, remote path mappings), which the `Arr
health issue` alert reports after an hour; a single failed import is a queue item, which
Decluttarr handles instead.

Seerr takes requests at `seerr.DOMAIN`, on the LAN and the tailnet, and runs on bastion, outside the guest, because it
needs Jellyfin; its database stays in bastion's shared PostgreSQL ([identity skill](../identity/SKILL.md)); it signs in to Jellyfin as the declared native admin to set itself up, and its Sonarr and Radarr
setup units start from a timer a minute after boot or a deploy, outside the switch, and retry until
the request profile exists in the guest, giving up after fifteen tries in an hour, since no
unit ordering crosses into it. Its login
takes a Jellyfin password and Seerr has no OIDC, so only accounts with a native Jellyfin password
(the admin) sign in; people who reach Jellyfin through Authelia have none. Requests go to Sonarr and Radarr on
`1080p Storage Efficient`, the profile Recyclarr syncs daily next to the TRaSH ones it already
manages. Its size caps (31.7 MB per minute) are Sonarr's and Radarr's quality definitions, which
every profile shares, so they cap 1080p in all of them. Recyclarr and Decluttarr talk only to the
apps, so they run in the namespace. Decluttarr clears stalled, slow, failed and finished downloads
from the queues, qBittorrent and SABnzbd, and searches for missing media, every 10 minutes at its
default; a download goes after five strikes.

Everything reaches qBittorrent from inside the namespace or the bridge, so nothing is exempt from
its login: Sonarr, Radarr, Decluttarr and the port-forward unit use `arr/qbittorrent-password`, and the
PBKDF2 hash qBittorrent checks is written into its config at each start from
`arr/qbittorrent-password-hash`, never into the store.

ProtonVPN forwards one random port, leased for 60 seconds over NAT-PMP from the gateway inside
the tunnel. `qbittorrent-port-forward` renews it every 45 seconds, opens it in its own chain of
the namespace's firewall, which otherwise drops unsolicited inbound traffic, and sets it as
qBittorrent's listen port. Each qBittorrent start rewrites its config from the store and drops
that port, so the unit is bound to qBittorrent and starts again with it. The `qbittorrent` uid is set to the one recorded as owning its state.

The usenet indexers take their keys from `arr/INDEXER-api-key` and rank ahead of the torrent
ones. Easynews has no Newznab API, so `easynews-indexer` serves one on the namespace's loopback
for Prowlarr, signing in with the Newshosting username and `arr/easynews-password`; Prowlarr
reaches it with `arr/easynews-api-key`. SABnzbd downloads from Newshosting, then Tweaknews, both
on the Newshosting password and with strict certificate checks. Prowlarr's indexer and
application setup units print no response bodies, which can echo the keys they sent. An indexer
that fails to apply (its site down, a key rejected) is logged and the rest still apply; the unit
succeeds, so one unreachable site never fails a deploy.

## The downloads guest

[downloads.nix](../../../modules/downloads.nix) is the MicroVM, `downloads`, built like the
agents' ([agents skill](../agents/SKILL.md)): cloud-hypervisor, a tap carrying a /24 only bastion
and the guest sit on ([_downloads.nix](../../../modules/_downloads.nix) holds its addresses for
both files), and the `downloads` nftables table, which masquerades the guest to the internet and
drops what it sends to bastion, to private addresses, to the tailnet and over IPv6, and new
connections forwarded towards it from any other network; replies to
connections bastion opens pass. The apps talk to indexers and peers, so one of them compromised
meets a second kernel before bastion. The guest's own uplink is bastion's, not the Proton tunnel:
it carries the tunnel's packets, and the namespace inside keeps the apps off it. The guest has no
login, no tailnet node and no sops identity. Its journal goes to its console, which is
`microvm@downloads`'s log on bastion, so Loki holds it; nothing on bastion sees a failed unit
inside the guest except through that log and the exporters. Unlike the agents' guest it restarts
whenever a deploy changes it, which stops downloads for the time of a boot. Its clock is in bastion's time zone.

What the guest gets from bastion, over virtiofs:

- The media dataset and the state directories of Sonarr, Radarr, Prowlarr, qBittorrent and
  SABnzbd, at the paths they have on bastion and with their datasets' mount options. Jellyfin's
  and Seerr's state is not shared. The accounts that own them keep their ids: nixflix pins most,
  and arr.nix restates qBittorrent's whole account, since nixflix forces it without a uid.
- The arr secrets, read-only, copied from sops into `/run/downloads-secrets` when the guest's
  virtiofs daemons start. A changed secret restarts those daemons and the guest with them. Seerr's
  API key stays on bastion; the three arr API keys are on both sides, for the exporters and Seerr.
- `/srv/backups/downloads`, where the guest's PostgreSQL dumps each arr database nightly, inside a
  backup root ([backups skill](../backups/SKILL.md)). The restore drill does not load these dumps, and
  nothing bounds what the guest writes there or into the state directories: `apps/srv` and
  `apps/nixflix` have no quota, so a compromised guest can fill them.

The guest's disk, `var.img` on `apps/agents`, holds `/var/lib`: PostgreSQL, Recyclarr and
Decluttarr. It is neither snapshotted nor backed up, so the dumps are the databases' only copy
outside it: before the arr apps start, `arr-restore` loads each database that has no table from
its dump, which is also how a lost disk comes back, and the nightly dump skips a database that
has no table, so a failed load never replaces a good dump with an empty one. `arr-handover` on
bastion writes the first dumps, from the databases bastion's PostgreSQL still holds from before
the move, and once only: its marker, `/srv/backups/downloads-handover/done`, and its temporary
files sit outside the share, since bastion's `postgres` must not write where the guest can plant
a link. Those old databases are left in place. When the generation being replaced still ran the
arr apps on bastion and the marker is less than a week old (a move redone after a rollback),
activation removes the dumps, the marker and the guest's `var.img`, so the handover starts again
from bastion's databases instead of resuming on the guest's older ones. After that week the
guest's databases are the ones that count, and an old generation booted by accident resets
nothing. A boot straight into the new generation has no previous one to look at; there the three
are removed by hand. `arr-dumps-fresh` on bastion fails daily, and so raises `Unit failed`
([monitoring skill](../monitoring/SKILL.md)), while a database's dump is older than two days.
