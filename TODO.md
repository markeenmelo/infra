# Rewrite TODO

Remaining work to retire `infra-old/`. One PR per line unless noted; order is the intended
sequence. Decisions are in [CLAUDE.md](CLAUDE.md); remove a line in the PR that lands it.

## Fleet plumbing

- [ ] Tailnet policy: move the literal addresses and hosts to fleet facts; drop the old fleet's
      grants and proton exit nodes as each host migrates.
      Revisit `group:members` reaching `bastion:443` now that the LAN proxy and Authelia landed.
- [ ] One NixOS VM test in `nix flake check` (boot, root rollback, `/persist` survives).
- [ ] Build cache for CI and clients: bastion remote builder + Harmonia; decide what CI uses.
      GitHub-hosted arm64 Linux and Apple Silicon macOS runners can build the aarch64 closures
      for it; check the macOS runner's memory against the closures first.
- [ ] Decide the shared password hash on racknerd (per-host `login.yaml` or no password on the edge).

## bastion

- [ ] After the install, drop by hand the old PostgreSQL databases of the apps not ported: Home
      Assistant, Mosquitto, SparkyFitness, OpenGym, live TV and UsenetCrawler.
- [ ] Jellyfin child account: confirm the SSO plugin leaves a user's parental limits alone at
      login, then declare the account with its limits.
- [ ] Frigate's person object filters (`min_area`, ratios, `threshold`) and zone `inertia`
      against false positives, tuned by the operator.
- [ ] OpenCloud data: after the install, move the files into `tank/opencloud` with `rclone copy`
      from `/srv/nextcloud/instance/data/USER/files` over OpenCloud's WebDAV
      (shares, links, versions and trash do not carry over), then destroy `tank/nextcloud` and
      drop its mount, snapshots and backup root.
- [ ] Monitoring: Prometheus, Loki, Alloy, Grafana dashboards and alerts, with ntfy as their
      first publisher (topics `alerts`, later `media`), and the desktop subscribers; backup
      metrics and alerts.
- [ ] Separate the household backup key from the laptop's: the old generation gave every repository
      one password, which the ThinkPad holds. `restic key add` a new
      `backups/restic-password` to the USB and pCloud repositories and remove the
      old key; `backups/thinkpad-password` keeps the old value.
- [ ] Remote builder + Harmonia cache for the fleet.
- [ ] UniFi OpenTofu project: the LAN wildcard record made by hand; keep bastion to the camera on
      554 and 2020, and no internet for the
      Cameras VLAN; drop the Home Assistant to IoT media rule.

## Laptops

- [ ] `thinkpad`: host, desktop profile, Stylix, Home Manager, power, backups; persist and back up
      `~/.local/state/infra` (OpenTofu state).
- [ ] `asahi`: host (evaluates in CI, builds on itself), desktop profile shared with thinkpad.
- [ ] Operator Home Manager: shell, tmux, neovim, dev tooling, shared across hosts.

## Closing out

- [ ] `ci-deploy`: deploy on merge from GitHub-hosted runners (Tailscale GitHub Action + deploy-rs),
      protected environment with manual approval gated by a path filter on access-changing files;
      its own key on the `deploy` account, which is root-equivalent.
- [ ] Remaining skills as their code lands (`monitoring`, `desktop`); update `nix`
      skill placement table.
- [ ] Delete `~/projects/infra-old/` (duplicate) and, when every host runs the new config,
      `infra/infra-old/` and its mention in CLAUDE.md.
