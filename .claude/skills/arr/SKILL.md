---
name: arr
description: "Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd, Seerr, Recyclarr and Decluttarr on bastion through nixflix: their logins and databases, the Proton WireGuard namespace they run in, ProtonVPN port forwarding, the firewall around the namespace, their tailnet-only web UIs, the torrent and usenet indexers, the Easynews bridge, the usenet servers, media requests and the quality profile. Use before touching modules/arr.nix, modules/easynews-indexer.pkg.nix or modules/decluttarr.pkg.nix, changing indexers, servers, quality profiles or download limits, rotating the WireGuard config or a provider credential, or debugging downloads, imports or the VPN."
---

# Arr apps

[arr.nix](../../../modules/arr.nix) runs Sonarr, Radarr, Prowlarr, qBittorrent and SABnzbd from
nixflix on the media datasets shared with Jellyfin ([jellyfin skill](../jellyfin/SKILL.md)), the
arr databases in the shared PostgreSQL over its socket ([identity skill](../identity/SKILL.md)).
nixflix wires Prowlarr to Sonarr and Radarr and both to qBittorrent and SABnzbd from the declared
API keys; its setup units apply settings after every start. Their bind address also goes in as an
environment variable, which wins over `config.xml`: the setup units can only reach an app at the
namespace address, so an address carried in an old `config.xml` would keep it unreachable. SABnzbd's config is regenerated from
Nix at each start, so its categories unit reruns with it; its queue and logs live in the state
dataset.

All of them run in nixflix's WireGuard namespace on Proton's config (`arr/proton-wireguard`,
generated with NAT-PMP on), so indexer searches, metadata and downloads leave only through the
tunnel. nixflix confines them together: an app inside cannot reach one outside. Their web UIs are
`sonarr.`, `radarr.`, `prowlarr.`, `qbittorrent.` and `sabnzbd.DOMAIN` through the LAN proxy for
tailnet clients only ([proxy skill](../proxy/SKILL.md)); the arr apps and SABnzbd log in as
`marcos` with `arr/password`. An nftables table drops forwarding across the namespace's bridge, so
nixflix's port mappings never expose the apps to the LAN, and lets only root (which nixflix's
setup units and the port-forward unit run as) and Caddy open new connections into the namespace,
and Seerr only to Sonarr and Radarr; replies to connections the apps open pass.

Seerr takes requests at `seerr.DOMAIN`, tailnet-only, and runs outside the namespace because it
needs Jellyfin; it signs in to Jellyfin as the declared native admin to set itself up. Its login
takes a Jellyfin password and Seerr has no OIDC, so only accounts with a native Jellyfin password
(the admin) sign in; people who reach Jellyfin through Authelia have none. Requests go to Sonarr and Radarr on
`1080p Storage Efficient`, the profile Recyclarr syncs daily next to the TRaSH ones it already
manages. Its size caps (31.7 MB per minute) are Sonarr's and Radarr's quality definitions, which
every profile shares, so they cap 1080p in all of them. Recyclarr and Decluttarr talk only to the
apps, so they run in the namespace. Decluttarr clears stalled, slow, failed and finished downloads
from the queues, qBittorrent and SABnzbd, and searches for missing media, every 10 minutes at its
default; a download goes after five strikes.

Everything reaches qBittorrent from inside the namespace or the bridge, so nothing is exempt from
its login: Sonarr, Radarr and the port-forward unit use `arr/qbittorrent-password`, and the
PBKDF2 hash qBittorrent checks is written into its config at each start from
`arr/qbittorrent-password-hash`, never into the store.

ProtonVPN forwards one random port, leased for 60 seconds over NAT-PMP from the gateway inside
the tunnel. `qbittorrent-port-forward` renews it every 45 seconds, opens it in its own chain of
the namespace's firewall, which otherwise drops unsolicited inbound traffic, and sets it as
qBittorrent's listen port. The `qbittorrent` uid is pinned to the one that owns its state.

The usenet indexers take their keys from `arr/INDEXER-api-key` and rank ahead of the torrent
ones. Easynews has no Newznab API, so `easynews-indexer` serves one on the namespace's loopback
for Prowlarr, signing in with the Newshosting username and `arr/easynews-password`; Prowlarr
reaches it with `arr/easynews-api-key`. SABnzbd downloads from Newshosting, then Tweaknews, both
on the Newshosting password and with strict certificate checks. Prowlarr's indexer and
application setup units print no response bodies, which can echo the keys they sent. An indexer
that fails to apply (its site down, a key rejected) is logged and the rest still apply; the unit
succeeds, so one unreachable site never fails a deploy.
