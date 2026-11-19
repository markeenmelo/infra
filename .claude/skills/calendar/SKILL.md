---
name: calendar
description: "Radicale on bastion: the household's CalDAV calendars at cal.DOMAIN, published to the internet, its accounts and their password hashes, the family calendar every account shares, where the collections live and how phones and Hermes connect. Use before touching modules/radicale.nix, adding or removing an account, changing a calendar password, sharing another calendar, or debugging calendar sync."
---

# Calendar

[radicale.nix](../../../modules/radicale.nix) runs Radicale on bastion's loopback, served at
`cal.DOMAIN` by both proxies and published to the internet ([proxy skill](../proxy/SKILL.md)),
since CalDAV clients sync from wherever the phone is and cannot pass a sign-in portal. The
unit is nixpkgs' sandboxed one, further limited to loopback traffic.

- **Accounts:** every person in `fleet.people` ([identity skill](../identity/SKILL.md)) plus
  `hermes`, for the agent ([hermes skill](../hermes/SKILL.md)). Each signs in with HTTP basic
  authentication. A person uses their Authelia password: Radicale checks the same argon2id
  hash, `authelia/USER-password-hash`, so a change there applies here at the next deploy. On
  `cal.DOMAIN` that password works alone, without the second factor, and every client stores
  it; the operator accepted that a leaked client password is also the Authelia first factor,
  and that guesses here skip Authelia's ban. Instead, a local CrowdSec scenario bans an
  address at the edge after a burst of refused sign-ins on this hostname, about one a minute
  sustained; clients first ask without credentials, so a sync costs one. A phone left with an old
  password gets its mobile address banned; at home it reaches the LAN proxy and is never banned.
  Sign-ins are cached briefly, since argon2id is costly on every request.
  `hermes` has its own bcrypt hash, `radicale/hermes-password-hash` in bastion's secrets
  ([secrets skill](../secrets/SKILL.md)).
- **Rights:** an account reads and writes its own collections and nothing of another's.
- **The family calendar:** one collection outside every home, linked into each account's home
  as `family`, so every client discovers it beside the account's own calendars and all of them
  write the same events. A client may write events there but cannot delete or replace the link
  itself. tmpfiles creates the collection and the links, again before each start of the unit
  since `/srv` mounts late; its properties file is
  written once, so a name or color a client sets later stays. Sharing another calendar is one
  more collection and link there.
- **State:** `/srv/radicale` on `apps/srv`, plain files, inside the `/srv` backup root
  ([backups skill](../backups/SKILL.md)). The account that owns it has a pinned id.

## Clients

- **Android:** DAVx⁵, base URL `https://cal.DOMAIN`, the account name and its password; it
  syncs into the system calendar, which any calendar app shows.
- **Browser:** Radicale's own page at the same address creates a calendar and uploads an
  `.ics` file, which is how a calendar exported elsewhere comes in.
- **Hermes:** the `hermes` account, over the public name, since its guest reaches nothing of
  bastion.

## The hermes password

From the dev shell:

```sh
p=$(openssl rand -base64 24); printf '%s\n' "$p"
printf %s "$p" | mkpasswd -m bcrypt -R 12 -s | jq -Rs 'rtrimstr("\n")' |
  sops set --value-stdin secrets/hosts/bastion.yaml '["radicale"]["hermes-password-hash"]'; unset p
```

The first line shows the password once, for Hermes's secrets; only the hash is stored.
