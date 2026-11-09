---
name: jellyfin
description: "Jellyfin on bastion through nixflix: the media server at jellyfin.DOMAIN, its Authelia sign-in through the K0lin SSO plugin, the native admin, Quick Connect for TV and mobile apps, parental controls, Quick Sync transcoding, the media and state datasets, and the nixflix input shared with the arr apps. Use before touching modules/jellyfin.nix, modules/nixflix.nix or modules/jellyfin-sso.pkg.nix, adding a person or a child account, or debugging playback, transcoding or sign-in."
---

# Jellyfin

[jellyfin.nix](../../../modules/jellyfin.nix) runs Jellyfin from the nixflix module
([nixflix.nix](../../../modules/nixflix.nix)), which every media app imports once: it sets nixflix's
state on `apps/nixflix` at `/srv/nixflix-state` and its media and downloads on `tank/media`, and
holds its directory setup until both are mounted. nixflix pins the users and groups the datasets
already belong to (`jellyfin` 146, `media` 169, and the arr apps' own), so a reinstall keeps them.
Settings, libraries, plugins and users are applied by nixflix's oneshot units through Jellyfin's
API after every start; configuration lives in Nix, not in the dashboard.

It is public at `jellyfin.` through both proxies ([proxy skill](../proxy/SKILL.md)), with its
admin API denied at the edge, so administration happens on the LAN or the tailnet. Jellyfin
trusts `X-Forwarded-For` only from the LAN proxy and racknerd.

## Sign-in

People sign in through Authelia with the K0lin SSO plugin, pinned in
[jellyfin-sso.pkg.nix](../../../modules/jellyfin-sso.pkg.nix) because nixflix's plugin manifest
has no Jellyfin 12 build of it. The client is confidential (`client_secret_post`); its secret
reaches the plugin from sops and Authelia holds the digest ([identity skill](../identity/SKILL.md)).
Membership of `jellyfin` lets a person in and `jellyfin-admins` makes them an admin; the plugin
rewrites admin status from those groups at every login. The login page's button starts the flow at
`/sso/OID/start/authelia`. Pushed authorization is off as a `shortcut:` in the module.

`marcos` is also a native admin with a password from sops, since nixflix needs one admin it can
manage, and the setup units use the API key. The edge denies password sign-in, so from the
internet the only ways in are Authelia and Quick Connect; native passwords work only on the LAN
and the tailnet. Each refused attempt carries `Edge-Denied`, so repeated password sign-ins from
outside earn a CrowdSec ban on every hostname, by design: away from home, use Quick Connect. TV and mobile apps cannot run the browser flow: they sign in with Quick Connect,
approved from a signed-in session.

A child account is a native user declared in `nixflix.jellyfin.users` with `mutable = false` and
parental limits (`maxParentalRating`, `blockUnratedItems`, `accessSchedules`), signed in on the TV
by Quick Connect approved from a session signed in as the child. Libraries are not split by
rating: limits come from TMDb's ratings, so a library's `metadataCountryCode` decides which rating
system applies. An SSO login adopts a native account of the same name, so jellyfin.nix asserts no
non-admin native user shares an Authelia username; the plugin otherwise never touches native
accounts nor anyone's parental limits.

## Media and transcoding

Libraries are Movies and Shows under `/srv/media/media/{movies,tv}`; the cache sits on
`tank/media` so trickplay and transcodes survive the root rollback. Transcoding and trickplay use
Quick Sync on the iGPU named by `fleet.renderDevice`, the only device the unit may open.
