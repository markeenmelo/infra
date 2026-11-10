# Rewrite TODO

Remaining work to retire `infra-old/`. One PR per line unless noted; order is the intended
sequence. Decisions are in [CLAUDE.md](CLAUDE.md); remove a line in the PR that lands it.

## Fleet plumbing

- [ ] Build the aarch64 closures (`asahi`, `mac`) in CI on GitHub's arm64 Linux and Apple Silicon
      macOS runners; check the macOS runner's memory against the closures first.

## bastion

- [ ] Frigate's person object filters (`min_area`, ratios, `threshold`) and zone `inertia`
      against false positives, tuned by the operator.
- [ ] Destroy the unmounted `tank/nextcloud` dataset once nothing is missed from it. It left the
      backup roots, so restic's copies age out under the prune policy in `modules/backups.nix`
      and the dataset then holds the only copy.
- [ ] Exporters and alerts for PostgreSQL and the apps (Authelia, Immich, Frigate, Jellyfin, the
      arr apps, Caddy requests) once the core set misses something; Sonarr and Radarr publishing to
      ntfy's `media` topic.

## Laptops

- [ ] `thinkpad`: a desktop switcher for the Proton exit nodes, on the mac too.
- [ ] `asahi`: host (evaluates in CI, builds on itself), desktop profile shared with thinkpad.
- [ ] Operator Home Manager: shell, tmux, neovim, dev tooling, shared across hosts.

## Closing out

- [ ] `ci-deploy`: deploy on merge from GitHub-hosted runners (Tailscale GitHub Action + deploy-rs),
      protected environment with manual approval gated by a path filter on access-changing files;
      its own key on the `deploy` account, which is root-equivalent.
- [ ] Delete `infra/infra-old/` and its mention in CLAUDE.md once every host runs the new config.
