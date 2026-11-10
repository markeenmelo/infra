# Rewrite TODO

Remaining work to retire `infra-old/`. One PR per line unless noted; order is the intended
sequence. Decisions are in [CLAUDE.md](CLAUDE.md); remove a line in the PR that lands it.

## bastion

- [ ] Sonarr and Radarr publishing to ntfy's `media` topic, which needs a path out of the VPN
      namespace to bastion's ntfy.

## Closing out

- [ ] Delete `infra/infra-old/` and its mention in CLAUDE.md once every host runs the new config.
