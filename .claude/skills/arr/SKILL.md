---
name: arr
description: "Sonarr, Radarr, Prowlarr and qBittorrent on bastion through nixflix: their logins and databases, the Proton WireGuard namespace qBittorrent and Prowlarr's SOCKS proxy run in, ProtonVPN port forwarding, the firewall around the namespace, the tailnet-only qBittorrent web UI, and the indexer list. Use before touching modules/arr.nix, changing indexers or download limits, rotating the WireGuard config, or debugging downloads, imports or the VPN."
---

# Arr apps

[arr.nix](../../../modules/arr.nix) runs Sonarr, Radarr and Prowlarr from nixflix on the media
datasets shared with Jellyfin ([jellyfin skill](../jellyfin/SKILL.md)), their databases in the
shared PostgreSQL ([identity skill](../identity/SKILL.md)). They bind to loopback and log in with
their own form login as `marcos`, reachable only through the LAN proxy on the LAN and the tailnet
([proxy skill](../proxy/SKILL.md)). nixflix wires Prowlarr to Sonarr and Radarr and both to
qBittorrent from the declared API keys; its setup units apply settings after every start.

qBittorrent runs in nixflix's WireGuard namespace on Proton's config (`arr/proton-wireguard`,
generated with NAT-PMP on), so its traffic leaves only through the tunnel. Prowlarr's public
torrent indexers go through `microsocks` in the same namespace, tagged `vpn`. An nftables table
drops forwarding across the namespace's bridge and lets only root, `media`, Prowlarr and Caddy
open connections into it; Jellyfin is refused although it is in `media`.

Everything reaches qBittorrent from the bridge address, so nothing is exempt from its login:
Sonarr and Radarr use `arr/qbittorrent-password`, and the PBKDF2 hash qBittorrent checks is
written into its config at each start from `arr/qbittorrent-password-hash`, never into the store.
Its web UI is `qbittorrent.DOMAIN`, for tailnet clients only.

ProtonVPN forwards one random port, leased for 60 seconds over NAT-PMP from the gateway inside
the tunnel. `qbittorrent-port-forward` renews it every 45 seconds, opens it in the namespace's
firewall, which otherwise drops unsolicited inbound traffic, and sets it as qBittorrent's listen
port. The `qbittorrent` uid is pinned to the one that owns its state.
