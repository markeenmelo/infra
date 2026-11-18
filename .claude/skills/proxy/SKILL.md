---
name: proxy
description: "The public edge: the passthrough on the edge host that forwards TLS unread to bastion's public listener, with its PROXY protocol trust; that listener on bastion, Caddy with a wildcard certificate by Porkbun DNS-01, the hostnames it serves, the headers it strips and the admin paths it denies; CrowdSec bans decided on bastion and enforced at the edge's firewall; where certificates, logs and ban state live; bastion's LAN proxy and the tailnet split DNS that keep home traffic off the WAN. Use before touching modules/edge.nix, modules/lan-proxy.nix, modules/caddy.nix or modules/crowdsec.nix, publishing or removing a hostname, or debugging HTTPS, name resolution of the domain, or bans."
---

# Edge proxy

[edge.nix](../../../modules/edge.nix) is the whole public surface, in two halves, so that the
cloud host never reads what it carries ([edge skill](../edge/SKILL.md)).

The `passthrough` role on the edge host is nginx: the stream module forwards TCP 443 to bastion
over the tailnet with PROXY protocol, and port 80 only redirects to https; there is no HTTP/3,
so the firewall opens no UDP. TLS ends on bastion, so the host holds no certificate and no
Porkbun key and keeps no access log; nginx comes from the binary cache, so the one-core host
compiles nothing. Since bastion sheds an abusive client only after the edge already holds its
connection open, the edge caps the connections one address may hold, and its connection ceiling
is raised well above nginx's default so one source cannot exhaust it.

The `public-proxy` role on bastion is a second Caddy listener on `fleet.publicPort`, in the LAN
proxy's process and holding its wildcard certificate, obtained from Let's Encrypt alone through
Porkbun DNS-01. It takes the client's address from the PROXY header of the edge host alone and
refuses a header from any other source; the firewall admits the port from that host on the
tailnet interface only, and the tailnet policy's test keeps the edge off the LAN proxy, the
cache and the state database ([opentofu skill](../opentofu/SKILL.md)). A connection that reaches
the listener with no header counts as its sender: the edge's own address is outside `countries`
and is aborted, so a passthrough that stops sending the header fails closed. The loopback
exemption in `policy` is for the edge's probes of its own port, which arrive with a loopback
client address; it also covers a local process on bastion, which reaches the apps on loopback
anyway.

Everything decided per request lives in `policy` in edge.nix: one `handle` per published
hostname, forwarding to the app's address and port. Anything else on the wildcard is aborted
without a response, so scanners learn nothing. The published apps authenticate natively, since
their mobile clients cannot pass a forward-auth portal, and so do the apps only bastion's LAN
proxy serves (Grafana through Authelia's OIDC, the arr apps with `arr/password`, Frigate);
nothing sits behind forward-auth. Authelia's portal is still published, because the apps' single
sign-on redirects there from wherever the user is.

Every app is reachable on the LAN and the tailnet, and a `public` one on the WAN as well; there
is no third tier. That includes ntfy, whose `alerts` topic describes the fleet and is readable
without a login.

Every forwarded request loses the `Remote-*` and `X-Forwarded-*` identity headers, so only
Authelia on bastion can set them, and every response gets the security headers in the site's `header` block: the ones marked `?` are defaults an app's own value replaces, and there is no Content-Security-Policy, since one policy cannot fit every app. Each app's
admin paths (Jellyfin's, including password changes, Immich's admin areas, and OpenCloud's user,
group and role management) are
answered 404 by the public listener as defence in depth, each app's own authorization being the primary control:
administering those apps happens over the LAN or the tailnet, never through the public hostname. Each app's `denied` list says which logins the public hostname still takes; bans there come from CrowdSec, and a per-address `rate_limit` zone answers 429 past a ceiling set above an Immich thumbnail burst.

Requests from outside `countries`, from the `hosting` networks (clouds and server hosts, where scanners run, Canadian addresses included) and from the `crawlers` user agents are aborted without a response before any app sees them, the answer an unpublished name gets, so a refusal reveals nothing; `/robots.txt` disallows everything. A household member abroad, or on a VPN that exits through a hosting network, uses the tailnet. The lookups use the DB-IP
country and ASN databases packaged in nixpkgs, so they update with the flake lock and need no account.
Tailnet clients never need the edge, even behind a foreign exit node: the split DNS sends the
domain to bastion directly.
An app module declares itself with `fleet.web.apps.SUBDOMAIN` (port, `public`, denied paths,
[caddy.nix](../../../modules/caddy.nix)): both proxies route an app to loopback, or to its
`address` when the app lives in another network namespace, and only a `public` one is served by
the public listener. No app port is open on any interface, so nothing reaches an app past the
denied paths and the country check. The wildcard record already
resolves it ([opentofu skill](../opentofu/SKILL.md#porkbun)), so publishing an app is a deploy of bastion. Certificates, the ACME account and the JSON access logs CrowdSec reads live
in Caddy's data and log directories under `/persist`; the log keeps no query strings, no
credential headers and no share tokens in paths, since the published apps carry credentials in
all three (the URI filters apply in sequence, so the query strip and every path redaction all
run), and Caddy rolls the file itself. The `caddyfile-HOST` check validates the generated
Caddyfile with the pinned Caddy, which also compiles every regex, and asserts on the adapted
config that identity headers are stripped before any proxying route, so a bad matcher, filter
or directive order fails CI instead of the edge.

[crowdsec.nix](../../../modules/crowdsec.nix) bans at the edge's firewall, not in Caddy. The
`crowdsec-engine` role on bastion tails the public listener's access log as a member of the
`caddy` group, the hub `caddy` collection parses it and
supplies the generic HTTP scenarios, and one local scenario bans an address after repeated
denials by the listener itself, which marks them with an `edge_denied` field in the access log and nothing in the response, so backend errors never
count; the community blocklist comes from the central API the setup unit registers with
on first boot. The engine serves ban decisions on `fleet.bansPort` to the tailnet;
`crowdsec-bouncer` on the edge pulls them and drops banned addresses in nftables, the firewall
backend of every host ([caddy.nix](../../../modules/caddy.nix)), before they cross the tailnet.
Bastion runs no bouncer of its own, since every public connection reaches it from the edge's
address. The bouncer's key is one value under two names, `crowdsec-bouncer-key` in the edge's
secrets file and `crowdsec/edge-bouncer-key` in bastion's
([secrets skill](../secrets/SKILL.md)), and reads decisions only; bastion registers it whenever
the API does not accept it, so a rotated key needs no command and an unchanged one leaves no
moment in which the edge is refused. The edge's bouncer restarts on failure, so it comes back by
itself after bastion was away, and a deploy of the edge does not hinge on bastion answering.
Bastion is still deployed first, so the key is known when the bouncer first asks. Ban length grows
with each repeat. A home browser resolving over DNS-over-HTTPS reaches the apps through the edge
instead of the LAN proxy, and a few admin pages there would ban the household's own address, so
Zen's enforced policies ([zen.nix](../../../modules/zen.nix)) turn DNS-over-HTTPS off. The hub is pinned to a commit so `cscli hub update` cannot change what the
engine runs; moving it is a lock-style bump of that literal. State under `/var/lib/crowdsec`
(database, hub, API credentials) persists, and the engine runs as a static user so the
persisted files keep their owner across reboots.

## LAN proxy

[lan-proxy.nix](../../../modules/lan-proxy.nix) is bastion's Caddy for the same wildcard name,
so LAN and tailnet clients reach the apps without crossing the WAN or the edge. Tailnet clients
get there through dnsmasq on bastion's tailnet interface, which the tailnet's split DNS queries
for the domain and which answers every name under it with bastion's tailnet address and refuses
everything else; LAN clients through the gateway's wildcard record to bastion's LAN address.
It serves 443 on the LAN and the tailnet, and the tailnet policy keeps the edge off it. Both
listeners share [caddy.nix](../../../modules/caddy.nix): the package, the Porkbun keys, the
persisted certificates, and the DNS-01 snippet, whose checks ask public resolvers, since
the LAN's resolver may answer the domain locally. It keeps no access log: app URLs carry
credentials and nothing reads it.

The Caddy package pins the plugin version and a hash that covers the Go module tree of both
Caddy and the plugin, so a nixpkgs bump that moves Caddy changes it as much as a plugin update.

The `certificate-watch` job in [lan-proxy.nix](../../../modules/lan-proxy.nix) asks Cert Spotter once a day for the certificates
issued for the domain and its subdomains, and counts those from the last week whose public key is
not the one the proxy serves; Caddy makes a new key at each renewal, so its own older certificates
fall outside the week. The query names the domain to that service. A failed query changes nothing
and fails no unit; the metric going stale has its own alert ([monitoring skill](../monitoring/SKILL.md)).
