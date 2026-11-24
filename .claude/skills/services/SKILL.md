---
name: services
description: "The apps on bastion: Authelia and the shared PostgreSQL, OpenCloud, Radicale calendars, Immich, Jellyfin, the arr apps and their downloads MicroVM, Frigate, the Dorian bot, and monitoring (Prometheus, Loki, Grafana, alerts, ntfy). Use before touching one of their modules, adding a person or an app, or debugging an app's sign-in, data, alerts or downloads."
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
| [arr.md](arr.md) | Sonarr, Radarr, Prowlarr, qBittorrent, SABnzbd, Seerr, Recyclarr, Decluttarr, the `downloads` MicroVM | `arr.nix`, `downloads.nix`, `vpn-watch.nix`, `easynews-indexer.pkg.nix`, `decluttarr.pkg.nix` |
| [frigate.md](frigate.md) | Frigate NVR | `frigate.nix` |
| [dorian.md](dorian.md) | Dorian Discord dice bot | `dorian.nix`, `dorian.pkg.nix` |
| [monitoring.md](monitoring.md) | Prometheus, Loki, Alloy, Grafana, alerts, ntfy | `monitoring.nix`, `ntfy.nix` |

What every app shares:

- **Reach:** a public app goes through both proxies with its admin paths denied at the edge, so
  it is administered from the LAN or the tailnet; a private one only through the LAN proxy
  ([proxy skill](../proxy/SKILL.md)).
- **Sign-in:** through Authelia, the client declared in `fleet.oidc.clients.ID` and roles taken
  from the `groups` claim ([identity.md](identity.md)).
- **Data:** on a declared dataset whose unit refuses to start without the mount, owned by a
  pinned uid so a reinstall keeps it ([bastion skill](../bastion/SKILL.md)); databases in the
  shared PostgreSQL; what is worth keeping sits under a backup root
  ([backups skill](../backups/SKILL.md)).
- **Secrets:** from `secrets/hosts/bastion.yaml`, read through `LoadCredential` or a `*File`
  option ([secrets skill](../secrets/SKILL.md)).
- **GPU:** only the iGPU named by `fleet.renderDevice`.
