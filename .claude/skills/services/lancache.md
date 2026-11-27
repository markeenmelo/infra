# Game download cache

[lancache.nix](../../../modules/lancache.nix) caches game and Windows Update downloads on bastion,
in the manner of lancache but on the NixOS nginx module, not lancache's containers. It answers on a
second address of its own, `fleet.hosts.bastion.lan.gameCache`, because Caddy holds ports 80 and
443 on every address: nftables redirects that address's 80 and 443 to nginx's own ports.

On port 80 nginx caches plain HTTP downloads with the slice module, keyed on the URI and 1 MB
range, so a game downloaded once comes from bastion for every other machine. Steam's clients share
one key whatever CDN host they name, from their user agent; other hosts are keyed by name. Upstream
names resolve through public resolvers, never the LAN's, since the LAN sends the cached names back
to the cache. On port 443 a stream server passes TLS through untouched, by its server name, for the
cached names that also serve HTTPS; nothing there is cached or decrypted. Both refuse every host outside `the list in `_game-cache-names.nix``: an HTTP request for another host gets 403 and a TLS connection for another name is closed, so the cache is no proxy to bastion's loopback services or the LAN. nginx binds only the cache address, which the firewall admits only after the redirect. Clients reach it from the LANs and over the tailnet, whose workstations reach the Homelab subnet through bastion's route, so the rule matches the address, not an interface; UniFi's firewall and the tailnet's grants decide who gets there.

The cache lives on the `tank/lancache` dataset (rebuildable, a 1 TB quota, no snapshots, outside the backup roots), and nginx
requires its mount, so the dataset must exist before bastion's deploy or nginx, and with it
Frigate's UI, does not start. Clients reach the cache only once DNS sends the download names to
`gameCache` ([opentofu skill](../opentofu/SKILL.md)).
