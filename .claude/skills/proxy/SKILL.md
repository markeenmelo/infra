---
name: proxy
description: "The public edge on racknerd: Caddy with a wildcard certificate by Porkbun DNS-01, the hostnames it forwards to bastion over the tailnet, the headers it strips and the admin paths it denies, where certificates and logs live. Use before touching modules/edge.nix, publishing or removing a public hostname, or debugging public HTTPS."
---

# Edge proxy

[edge.nix](../../../modules/edge.nix) is racknerd's whole public surface: Caddy on 443, with 80
only redirecting there, one wildcard certificate for the domain obtained through Porkbun DNS-01 with the keys in
`secrets/porkbun/api.yaml` ([secrets skill](../secrets/SKILL.md)), and one `handle` per published
hostname forwarding to a bastion port over the tailnet. Anything else on the wildcard is aborted.
The tailnet policy must let racknerd reach each backend port ([opentofu skill](../opentofu/SKILL.md)).

Every forwarded request loses the `Remote-*` identity headers, so only Authelia on bastion can set
them, and gets the security headers the old edge sent. Admin-only paths of Jellyfin and Home
Assistant's onboarding are denied at the edge; a native login still works there, so rate limiting
and bans come from CrowdSec.

Publishing an app adds its subdomain and bastion port to `apps`; the DNS record and the tailnet
grant are separate changes. Certificates, the ACME account and the JSON access logs CrowdSec reads live
in Caddy's data and log directories under `/persist`; the log keeps no query strings and no app
token headers, since the published apps carry credentials in both. racknerd resolves over
DNS-over-TLS on its own ([networking.nix](../../../modules/hosts/racknerd/networking.nix)) and
servers ignore tailnet DNS ([server.nix](../../../modules/server.nix)), so the DNS-01 check never
depends on the tailnet or bastion.

The Caddy package pins the plugin version and its hash; a plugin update changes both.
