---
name: calendar
description: "Radicale on bastion: the household's CalDAV calendars and CardDAV contacts behind OpenCloud's sign-in at cloud.DOMAIN/caldav and /carddav, the app tokens clients use, the family calendar every account shares, where the collections live and how phones connect. Use before touching modules/radicale.nix, OpenCloud's app tokens, sharing another calendar, or debugging calendar or contact sync."
---

# Calendar

[radicale.nix](../../../modules/radicale.nix) runs Radicale on bastion's loopback behind
OpenCloud's proxy ([opencloud skill](../opencloud/SKILL.md)), the way upstream's own deployment
does: the proxy serves `/caldav/`, `/carddav/` and their `/.well-known` names on
`cloud.DOMAIN`, signs the request in, and hands Radicale the account's OpenCloud id in
`X-Remote-User`. Radicale trusts that header, so a loopback guard lets only OpenCloud's account
connect to it, and the unit itself takes loopback traffic only. Nothing else publishes it.
OpenCloud's proxy lets `OPTIONS` through unauthenticated and then leaves the header as the
client sent it, so both Caddy listeners strip `X-Remote-User` with the other identity headers
([caddy.nix](../../../modules/caddy.nix)); a process on bastion that calls OpenCloud's port
directly can still name any user. Each route also sends `X-Forwarded-Proto`: Radicale strips
the `/caldav` or `/carddav` prefix (`X-Script-Name`) only from a request that names a proxy,
and OpenCloud's sets no forwarding header.

- **Accounts:** whoever can sign in to OpenCloud. A calendar client cannot do OpenID Connect,
  so it signs in with the OpenCloud user name and an app token the person creates in
  OpenCloud's settings, one per device, revocable there. Each home is named after the
  account's OpenCloud id, a UUID, not the user name, and holds a `Calendar` and `Contacts`
  that Radicale creates at the first sign-in.
- **Rights:** an account reads and writes its own collections and nothing of another's.
- **The family calendar:** one collection outside every home, linked into each home as
  `family`, so every client discovers it beside the account's own calendars and all of them
  write the same events. A client may write events there but cannot delete or replace the
  link. Since homes appear only at a first sign-in, under ids nobody knows ahead, a path unit
  adds the link whenever a home appears, at each start of Radicale and every ten minutes, which
  catches a home created while a pass was running; a phone set up in
  that first moment shows `family` after its next refresh of the collection list. tmpfiles
  creates the shared collection, again before each start since `/srv` mounts late; its
  properties file is written once, so a name or color a client sets later stays.
- **State:** `/srv/radicale` on `apps/srv`, plain files, inside the `/srv` backup root
  ([backups skill](../backups/SKILL.md)). The account that owns it has a pinned id.

## Clients

- **Android:** DAVx⁵, "Login with URL and user name", base URL `https://cloud.DOMAIN`, the
  OpenCloud user name and an app token; it syncs calendars and contacts into the system apps.
- **Hermes:** none yet; it would need an OpenCloud account of its own.
- There is no web page: Radicale's is off, and a calendar exported elsewhere comes in through
  a client's import.
