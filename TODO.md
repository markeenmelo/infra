# Rewrite TODO

Remaining work to retire `infra-old/`. One PR per line unless noted; order is the intended
sequence. Decisions are in [CLAUDE.md](CLAUDE.md); remove a line in the PR that lands it.

## Fleet plumbing

- [ ] Build the aarch64 closures (`asahi`, `mac`) in CI on GitHub's arm64 Linux and Apple Silicon
      macOS runners; check the macOS runner's memory against the closures first.

## bastion

- [ ] Exporters and alerts for PostgreSQL and the apps (Authelia, Immich, Frigate, Jellyfin, the
      arr apps, Caddy requests) once the core set misses something; Sonarr and Radarr publishing to
      ntfy's `media` topic.

## Laptops

- [ ] `asahi`: host (evaluates in CI, builds on itself), desktop profile shared with thinkpad.

## Closing out

- [ ] Delete `infra/infra-old/` and its mention in CLAUDE.md once every host runs the new config.
