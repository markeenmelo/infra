# Rewrite TODO

Remaining work to retire `infra-old/`. One PR per line unless noted; order is the intended
sequence. Decisions are in [CLAUDE.md](CLAUDE.md); remove a line in the PR that lands it.

## Fleet plumbing

- [ ] Proton exit nodes on bastion (`proton-ca`, `proton-us`, `proton-br`): the old generation
      advertised them on the tailnet and the new bastion does not yet; the policy keeps their
      keys, tag and approver.
- [ ] One NixOS VM test in `nix flake check` (boot, root rollback, `/persist` survives).
- [ ] Once CI outgrows GitHub's 10 GB Actions cache: let CI substitute from bastion's cache through
      the Tailscale GitHub Action as an ephemeral tagged node allowed only port 5005, with the
      credential reachable only from this repository's branches (never fork PRs). Decide whether
      the laptops substitute from it. GitHub-hosted arm64 Linux and Apple Silicon macOS runners
      can build the aarch64 closures; check the macOS runner's memory against the closures first.

## bastion

- [ ] Jellyfin child account: confirm the SSO plugin leaves a user's parental limits alone at
      login, then declare the account with its limits.
- [ ] Frigate's person object filters (`min_area`, ratios, `threshold`) and zone `inertia`
      against false positives, tuned by the operator.
- [ ] Destroy the unmounted `tank/nextcloud` dataset once nothing is missed from it. It left the
      backup roots, so restic's copies age out under the prune policy in `modules/backups.nix`
      and the dataset then holds the only copy.
- [ ] Monitoring: Prometheus, Loki, Alloy, Grafana dashboards and alerts, with ntfy as their
      first publisher (topics `alerts`, later `media`), and the desktop subscribers; backup
      metrics and alerts.
- [ ] Separate the household backup key from the laptop's: the old generation gave every repository
      one password, which the ThinkPad holds. `restic key add` a new
      `backups/restic-password` to the USB and pCloud repositories and remove the
      old key; `backups/thinkpad-password` keeps the old value.
- [ ] UniFi OpenTofu project: the LAN wildcard record made by hand; keep bastion to the camera on
      554 and 2020, and no internet for the
      Cameras VLAN; drop the Home Assistant to IoT media rule.

## Laptops

- [ ] `thinkpad`: host, desktop profile, Stylix, Home Manager, power, backups; persist and back up
      `~/.local/state/infra` (OpenTofu state); a NixOS `remote-builds` with its own builder key, so
      its deploys build on bastion like the mac's.
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
