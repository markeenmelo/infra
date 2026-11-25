# Arr apps

[arr.nix](../../../modules/arr.nix) runs Sonarr, Radarr, Prowlarr, qBittorrent and SABnzbd from
nixflix on bastion, on the media datasets shared with Jellyfin ([jellyfin](jellyfin.md)), the arr
databases in bastion's shared PostgreSQL ([identity](identity.md)). The file has two halves:
`namespaced`, the apps in the namespace, and `host`, which imports it and adds the secrets, Seerr, the
exporters, the proxy entries and the firewall; the secrets the apps read are linked under
`/run/arr-secrets`.
nixflix wires Prowlarr to Sonarr and Radarr and both to qBittorrent and SABnzbd from the declared
API keys; its setup units apply settings after every start. Their bind address also goes in as an
environment variable, which wins over `config.xml`: the setup units can only reach an app at the
namespace address, so an address carried in an old `config.xml` would keep it unreachable. SABnzbd's config is regenerated from
Nix at each start, so its categories unit reruns with it; its queue and logs live in the state
dataset.

All of them run in nixflix's WireGuard namespace on Private Internet Access, region `ca`
(Montreal; PIA forwards no port in the US), so indexer searches, metadata and downloads leave
only through the tunnel. PIA has no static WireGuard config: each start of the namespace signs in
with `pia/{username,password}`, registers a new key with one of the region's servers and writes the
config under `/run` ([vpn-watch.nix](../../../modules/vpn-watch.nix)), so a restart is a new
server and a new key. The account must not need a one-time code at that sign-in. Root on bastion
therefore holds the whole PIA account, not one tunnel key. nixflix confines them together: an app inside cannot reach one outside.
[vpn-watch.nix](../../../modules/vpn-watch.nix) restarts the tunnel when it fails or its handshake
goes stale, and starts the confined apps again each time it comes up. Their web UIs are
`sonarr.`, `radarr.`, `prowlarr.`, `qbittorrent.` and `sabnzbd.DOMAIN` through the LAN proxy, on
the LAN and the tailnet ([proxy skill](../proxy/SKILL.md)); the arr apps and SABnzbd log in as
`marcos` with `arr/password`. The `arr` nftables table drops
anything forwarded through the namespace's bridge and lets only root and Caddy open new
connections into the namespace, Seerr only to Sonarr and Radarr, and the `exportarr` user only
to the three arr apps. It also drops every new connection the namespace
opens towards bastion itself, so the apps reach none of bastion's listeners; replies to bastion's
own connections pass. One exportarr exporter per app publishes its
health checks (indexers, download clients, root folders, remote path mappings), which the `Arr
health issue` alert reports after an hour; a single failed import is a queue item, which
Decluttarr handles instead.

Seerr takes requests at `seerr.DOMAIN`, on the LAN and the tailnet, and runs outside the namespace because it
needs Jellyfin; its database stays in bastion's shared PostgreSQL ([identity](identity.md)); it signs in to Jellyfin as the declared native admin to set itself up, and its Sonarr and Radarr
setup units start from a timer a minute after boot or a deploy that changes them, outside the
switch, and retry until
the request profile exists, giving up after fifteen tries in an hour, since no
unit ordering crosses into it. Its login
takes a Jellyfin password and Seerr has no OIDC, so only accounts with a native Jellyfin password
(the admin) sign in; people who reach Jellyfin through Authelia have none. Requests go to Sonarr and Radarr on
`1080p Storage Efficient`, the profile Recyclarr syncs daily next to the TRaSH ones it already
manages. Its size caps are Sonarr's and Radarr's quality definitions, which
every profile shares, so they cap 1080p in all of them. Recyclarr and Decluttarr talk only to the
apps, so they run in the namespace. Decluttarr clears stalled, slow, failed and finished downloads
from the queues, qBittorrent and SABnzbd, and searches for missing media, every 10 minutes at its
default; a download goes after five strikes.

Everything reaches qBittorrent from inside the namespace or the bridge, so nothing is exempt from
its login: Sonarr, Radarr, Decluttarr and the port-forward unit use `arr/qbittorrent-password`, and the
PBKDF2 hash qBittorrent checks is written into its config at each start from
`arr/qbittorrent-password-hash`, never into the store.

PIA forwards one random port per server, valid for about two months and dropped unless bound
again every 15 minutes through the tunnel's gateway. `qbittorrent-port-forward` signs in through
the tunnel, asks for the port, binds it every 15 minutes, opens it in its own chain of
the namespace's firewall, which otherwise drops unsolicited inbound traffic, and sets it as
qBittorrent's listen port. Each qBittorrent start rewrites its config from the store and drops
that port, so the unit is bound to qBittorrent and starts again with it. The `qbittorrent` uid is the one bastion had allocated, which owns its state.

The usenet indexers take their keys from `arr/INDEXER-api-key` and rank ahead of the torrent
ones. Easynews has no Newznab API, so `easynews-indexer` serves one on the namespace's loopback
for Prowlarr, signing in with the Newshosting username and `arr/easynews-password`; Prowlarr
reaches it with `arr/easynews-api-key`. SABnzbd downloads from Newshosting, then Tweaknews, both
on the Newshosting password and with strict certificate checks. Prowlarr's indexer and
application setup units print no response bodies, which can echo the keys they sent. An indexer
that fails to apply (its site down, a key rejected) is logged and the rest still apply; the unit
succeeds, so one unreachable site never fails a deploy.

## Return from the downloads guest

The apps ran in a MicroVM of their own for a while, with their databases in its PostgreSQL and
nightly dumps in `/srv/backups/downloads`. `arr-return` runs before every arr unit and stops the
guest if it still runs. It returns when the guest took over once (`downloads-handover/done`) and
`downloads-handover/returned` is missing, or when the dumps differ from those it last returned
(`returned` holds their hash; the guest sets the files' times, so they are not trusted);
otherwise it does nothing. Each dump must be a regular file from the last two days and not dated
in the future; a first return refuses otherwise, while after a return such dumps are logged and
the databases kept, so the guest cannot keep the apps down. Since the guest is untrusted, psql
loads each one under a random `\restrict` key the guest cannot know, in place of the dump's own,
so any meta-command in it (`\!`, `\copy`) stops the load; it runs as the app's user inside a
sandbox with no network. Every dump goes into a temporary database first, and only when all three
loaded are they swapped for bastion's and `returned` touched.

A rollback to a generation with the guest re-seeds it from bastion, and its dumps come back on the
next move, so the side that ran last wins. Changes made in the guest after its last nightly dump
are lost. A failed `arr-return` fails the switch, and the rollback re-seeds the guest from
bastion's stale databases, keeping its own disk as `var.img.replaced-TIME` and its dumps under
`downloads-handover/replaced-TIME` for recovery by hand; check that every dump is from the last
night before deploying. The `-logs` databases stay as they were.
