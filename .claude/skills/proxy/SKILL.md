---
name: proxy
description: "The public edge on racknerd: Caddy with a wildcard certificate by Porkbun DNS-01, the hostnames it forwards to bastion over the tailnet, the headers it strips and the admin paths it denies, where certificates and logs live. Use before touching modules/edge.nix, publishing or removing a public hostname, or debugging public HTTPS."
---

# Edge proxy

[edge.nix](../../../modules/edge.nix) is racknerd's whole public surface: Caddy on 443, with 80
only redirecting there, one wildcard certificate for the domain obtained through Porkbun DNS-01 with the keys in
`secrets/porkbun/api.yaml` ([secrets skill](../secrets/SKILL.md)), and one `handle` per published
hostname forwarding to a bastion port over the tailnet. Anything else on the wildcard is aborted
without a response, so scanners learn nothing. The published apps authenticate natively, since
their mobile clients cannot pass a forward-auth portal; Authelia guards the admin apps that only
bastion's LAN proxy serves. Its portal is still published, because the apps' single sign-on
redirects there from wherever the user is.
The tailnet policy must let racknerd reach each backend port ([opentofu skill](../opentofu/SKILL.md)).

Every forwarded request loses the `Remote-*` identity headers, so only Authelia on bastion can set
them, and gets the security headers the old edge sent. Jellyfin's admin paths, including password
changes, and Home Assistant's onboarding are denied at the edge: administering those apps and
onboarding a fresh Home Assistant happen over the LAN or the tailnet, never through the public
hostname. A native login still works there, so rate limiting and bans come from CrowdSec.

Publishing an app adds its subdomain and bastion port to `apps`; the DNS record and the tailnet
grant are separate changes. Certificates, the ACME account and the JSON access logs CrowdSec reads live
in Caddy's data and log directories under `/persist`; the log keeps no query strings, no
credential headers and no share tokens in paths, since the published apps carry credentials in
all three, and Caddy rolls the file itself. The `caddyfile-HOST` check adapts the generated
Caddyfile with the pinned Caddy, so a bad matcher or filter fails CI instead of the edge. racknerd resolves over
DNS-over-TLS on its own ([networking.nix](../../../modules/hosts/racknerd/networking.nix)) and
servers ignore tailnet DNS ([server.nix](../../../modules/server.nix)), so the DNS-01 check never
depends on the tailnet or bastion.

The Caddy package pins the plugin version and a hash that covers the Go module tree of both
Caddy and the plugin, so a nixpkgs bump that moves Caddy changes it as much as a plugin update.
