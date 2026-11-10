---
name: proxy
description: "The public edge on racknerd: Caddy with a wildcard certificate by Porkbun DNS-01, the hostnames it forwards to bastion over the tailnet, the headers it strips and the admin paths it denies, CrowdSec bans at the firewall, where certificates, logs and ban state live; bastion's LAN proxy and the tailnet split DNS that keep home traffic off the WAN. Use before touching modules/edge.nix, modules/lan-proxy.nix, modules/caddy.nix or modules/crowdsec.nix, publishing or removing a hostname, or debugging HTTPS, name resolution of the domain, or bans."
---

# Edge proxy

[edge.nix](../../../modules/edge.nix) is racknerd's whole public surface: Caddy on 443, with 80
only redirecting there, one wildcard certificate for the domain obtained through Porkbun DNS-01 with the keys in
`secrets/porkbun/api.yaml` ([secrets skill](../secrets/SKILL.md)), and one `handle` per published
hostname forwarding to a bastion port over the tailnet. Anything else on the wildcard is aborted
without a response, so scanners learn nothing. The published apps authenticate natively, since
their mobile clients cannot pass a forward-auth portal, and so do the apps only bastion's LAN
proxy serves (Grafana through Authelia's OIDC, the arr apps with `arr/password`, Frigate);
nothing sits behind forward-auth. Authelia's portal is still published, because the apps' single
sign-on redirects there from wherever the user is.

Every app is reachable on the LAN and the tailnet, and a `public` one on the WAN as well. The one
exception is ntfy, whose `alerts` topic describes the fleet and is readable without a login, so
it is `tailnetOnly`.
The tailnet policy must let racknerd reach each backend port ([opentofu skill](../opentofu/SKILL.md)).

Every forwarded request loses the `Remote-*` and `X-Forwarded-*` identity headers, so only
Authelia on bastion can set them, and gets the security headers the old edge sent. Each app's
admin paths (Jellyfin's, including password changes, Immich's admin areas, and OpenCloud's user,
group and role management) are
denied at the edge as defence in depth, each app's own authorization being the primary control:
administering those apps happens over the LAN or the tailnet, never through the public hostname. A native login still works there, so rate limiting and bans come from CrowdSec.

Requests from outside `countries` get a 403 before any app sees them; the lookup uses the DB-IP
country database packaged in nixpkgs, so it updates with the flake lock and needs no account.
Tailnet clients never need the edge, even behind a foreign exit node: the split DNS sends the
domain to bastion directly.
An app module declares itself with `fleet.web.apps.SUBDOMAIN` (port, `public`, denied paths,
[caddy.nix](../../../modules/caddy.nix)): the LAN proxy routes every app to loopback, or to its
`address` when the app lives in another network namespace, refuses non-tailnet clients and
bastion's own tailnet address (which any local process could borrow) for a `tailnetOnly` app, and
only a `public` one is forwarded by the edge and gets its port opened on the tailnet interface,
to racknerd's address alone, so a tailnet grant mistake cannot let a client skip the edge's
denied paths and country check. The wildcard record already
resolves it ([opentofu skill](../opentofu/SKILL.md#porkbun)) and the tailnet grant follows from the same fact on the next `tofu` apply of the tailscale project. Certificates, the ACME account and the JSON access logs CrowdSec reads live
in Caddy's data and log directories under `/persist`; the log keeps no query strings, no
credential headers and no share tokens in paths, since the published apps carry credentials in
all three (the URI filters apply in sequence, so the query strip and every path redaction all
run), and Caddy rolls the file itself. The `caddyfile-HOST` check validates the generated
Caddyfile with the pinned Caddy, which also compiles every regex, and asserts on the adapted
config that identity headers are stripped before any proxying route, so a bad matcher, filter
or directive order fails CI instead of the edge. racknerd resolves over
DNS-over-TLS on its own ([networking.nix](../../../modules/hosts/racknerd/networking.nix)) and
servers ignore tailnet DNS ([server.nix](../../../modules/server.nix)), so the DNS-01 check never
depends on the tailnet or bastion.

[crowdsec.nix](../../../modules/crowdsec.nix) bans at the firewall, not in Caddy: the engine
tails the access log as a member of the `caddy` group, the hub `caddy` collection parses it and
supplies the generic HTTP scenarios, and one local scenario bans an address after repeated
denials by the edge itself, which marks them with a response header so backend 403s never
count; the community blocklist comes from the central API the setup unit registers with
on first boot. The firewall bouncer registers itself with the local API and drops banned
addresses in nftables, which is why the server uses the nftables backend. Ban length grows
with each repeat. The hub is pinned to a commit so `cscli hub update` cannot change what the
engine runs; moving it is a lock-style bump of that literal. State under `/var/lib/crowdsec`
(database, hub, API credentials) persists, and the engine runs as a static user so the
persisted files keep their owner across reboots.

## LAN proxy

[lan-proxy.nix](../../../modules/lan-proxy.nix) is bastion's Caddy for the same wildcard name,
so LAN and tailnet clients reach the apps without crossing the WAN or racknerd. Tailnet clients
get there through dnsmasq on bastion's tailnet interface, which the tailnet's split DNS queries
for the domain and which answers every name under it with bastion's tailnet address and refuses
everything else; LAN clients through the gateway's wildcard record to bastion's LAN address.
It serves 443 on the LAN and the tailnet, and the tailnet policy keeps racknerd off it. Both
proxies share [caddy.nix](../../../modules/caddy.nix): the package, the Porkbun keys, the
persisted certificates, and the DNS-01 snippet, whose checks ask public resolvers, since
the LAN's resolver may answer the domain locally. It keeps no access log: app URLs carry
credentials and nothing reads it.

The Caddy package pins the plugin version and a hash that covers the Go module tree of both
Caddy and the plugin, so a nixpkgs bump that moves Caddy changes it as much as a plugin update.
