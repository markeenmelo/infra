---
name: services
description: "The apps on bastion: Authelia and the shared PostgreSQL, OpenCloud, Radicale calendars and contacts, Immich, Jellyfin and nixflix, the arr apps with their PIA VPN namespace, Frigate cameras, the Dorian bot, monitoring (Prometheus, Loki, Alloy, Grafana, alerts, ntfy) and the game download cache. Use before touching modules/{authelia,postgresql,opencloud,radicale,immich,jellyfin,nixflix,arr,vpn-watch,frigate,dorian,monitoring,ntfy,lancache}.nix or their *.pkg.nix pins, adding a person or an app, rotating an app credential, or debugging sign-in, sync, transcoding, downloads, cameras, alerts or notifications."
---

# Services

Read the file for the app you touch; each holds what its module cannot say: procedures, gotchas
and the decisions taken against.

| File | App | Modules |
|---|---|---|
| [identity.md](identity.md) | Authelia, OIDC clients, people, shared PostgreSQL | `authelia.nix`, `postgresql.nix` |
| [opencloud.md](opencloud.md) | OpenCloud file sync | `opencloud.nix` |
| [calendar.md](calendar.md) | Radicale CalDAV and CardDAV behind OpenCloud | `radicale.nix` |
| [immich.md](immich.md) | Immich photos | `immich.nix` |
| [jellyfin.md](jellyfin.md) | Jellyfin through nixflix | `jellyfin.nix`, `nixflix.nix`, `jellyfin-sso.pkg.nix` |
| [arr.md](arr.md) | Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd, Seerr, Recyclarr, Decluttarr | `arr.nix`, `vpn-watch.nix`, `easynews-indexer.pkg.nix`, `decluttarr.pkg.nix` |
| [frigate.md](frigate.md) | Frigate NVR | `frigate.nix` |
| [dorian.md](dorian.md) | Dorian Discord dice bot | `dorian.nix`, `dorian.pkg.nix` |
| [monitoring.md](monitoring.md) | Prometheus, Loki, Alloy, Grafana, alerts, ntfy | `monitoring.nix`, `ntfy.nix` |
| [lancache.md](lancache.md) | Game and Windows Update download cache | `lancache.nix` |

The rules apps share live elsewhere: reach through the proxies in the
[proxy skill](../proxy/SKILL.md), sign-in and the shared PostgreSQL in [identity.md](identity.md),
datasets and pinned ids in [hosts: bastion](../hosts/bastion.md), backup roots in the
[backups skill](../backups/SKILL.md), and how a unit reads a secret in the
[operating: secrets](../operating/secrets.md). Not every app follows them: Frigate, the arr apps and
SABnzbd keep their own logins, Radicale is reached with OpenCloud app tokens, Dorian serves
nothing, OpenCloud keeps its own secrets in a generated config. Each file says where its app differs.
