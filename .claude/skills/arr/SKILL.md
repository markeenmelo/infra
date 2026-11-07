---
name: arr
description: "Sonarr, Radarr, Prowlarr and qBittorrent on bastion through nixflix: their logins and databases, the Proton WireGuard namespace all four run in, ProtonVPN port forwarding, the firewall around the namespace, their tailnet-only web UIs, and the indexer list. Use before touching modules/arr.nix, changing indexers or download limits, rotating the WireGuard config, or debugging downloads, imports or the VPN."
---

# Arr apps

[arr.nix](../../../modules/arr.nix) runs Sonarr, Radarr, Prowlarr and qBittorrent from nixflix on
the media datasets shared with Jellyfin ([jellyfin skill](../jellyfin/SKILL.md)), the arr
databases in the shared PostgreSQL over its socket ([identity skill](../identity/SKILL.md)).
nixflix wires Prowlarr to Sonarr and Radarr and both to qBittorrent from the declared API keys;
its setup units apply settings after every start.

All four run in nixflix's WireGuard namespace on Proton's config (`arr/proton-wireguard`,
generated with NAT-PMP on), so indexer searches, metadata and downloads leave only through the
tunnel. nixflix confines them together: an app inside cannot reach one outside. Their web UIs are
`sonarr.`, `radarr.`, `prowlarr.` and `qbittorrent.DOMAIN` through the LAN proxy for tailnet
clients only ([proxy skill](../proxy/SKILL.md)); the arr apps log in as `marcos` with
`arr/password`. An nftables table drops forwarding across the namespace's bridge, so nixflix's
port mappings never expose the apps to the LAN, and lets only root and Caddy open connections
into the namespace.

Everything reaches qBittorrent from inside the namespace or the bridge, so nothing is exempt from
its login: Sonarr, Radarr and the port-forward unit use `arr/qbittorrent-password`, and the
PBKDF2 hash qBittorrent checks is written into its config at each start from
`arr/qbittorrent-password-hash`, never into the store.

ProtonVPN forwards one random port, leased for 60 seconds over NAT-PMP from the gateway inside
the tunnel. `qbittorrent-port-forward` renews it every 45 seconds, opens it in its own chain of
the namespace's firewall, which otherwise drops unsolicited inbound traffic, and sets it as
qBittorrent's listen port. The `qbittorrent` uid is pinned to the one that owns its state.
