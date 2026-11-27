# Game download cache

[lancache.nix](../../../modules/lancache.nix) caches game and Windows Update downloads on bastion,
in the manner of lancache but on the NixOS nginx module, not lancache's containers. It answers
on a second address of its own, `fleet.hosts.bastion.lan.gameCache`, because Caddy holds ports
80 and 443 on every address: nftables redirects that address's 80 and 443 to nginx's own ports.

On port 80 nginx caches plain HTTP downloads with the slice module, keyed on the URI and 1 MB
range, so a game downloaded once comes from bastion for every other machine. Steam's clients
share one key whatever CDN host they name, from their user agent; other hosts are keyed by
name. Upstream names resolve through public resolvers, never the LAN's, since the LAN sends
the cached names back to the cache. On port 443 a stream server passes TLS through untouched,
by its server name, for the cached names that also serve HTTPS; nothing there is cached or
decrypted. Only Steam's depot content (`/depot/<id>/...`), which is content-addressed and never
changes at its URL, is kept for ten years whatever its headers say; every other response follows
its upstream's Cache-Control (a day when it sends none), so manifests republished at fixed URLs,
such as Windows' certificate trust lists or Office's version files, stay current. Both refuse
every host outside [the names list](../../../modules/_game-cache-names.nix): an HTTP request
for another host gets 403 and a TLS connection for another name is closed, so the cache is no
proxy to bastion's loopback services or the LAN. nginx binds only the cache address, which the
firewall admits only after the redirect. Clients reach it from the LANs and over the tailnet,
whose workstations reach the Homelab subnet through bastion's route, so the rule matches the
address, not an interface; UniFi's firewall and the tailnet's grants decide who gets there.

The cache lives on the `tank/lancache` dataset (rebuildable, a 1 TB quota, no snapshots, outside
the backup roots), and nginx requires its mount, so the dataset must exist before bastion's
deploy or nginx, and with it Frigate's UI, does not start. DNS sends the download names to
`gameCache` for every client: the gateway answers LAN clients from UniFi records ([opentofu
skill](../opentofu/SKILL.md)), with firewall rules admitting Home and Kids to the cache, and
the tailnet's split DNS sends the workstations to bastion's dnsmasq, which answers the same;
their traffic to the Homelab subnet runs over the tailnet, where a grant admits the admin
clients to the cache's ports 80 and 443.

The tailnet's split DNS for these names is tailnet-wide, an operator's choice: every device that
takes the tailnet's DNS resolves them to the cache wherever it is, so away from home a miss
comes over the home uplink, the names stop resolving while bastion is down; members' devices
hold the same grant as the admin clients, since macOS and Windows clients take bastion's subnet
routes even at home.
