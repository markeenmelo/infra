# Rewrite TODO

Remaining work to retire `infra-old/`. One PR per line unless noted; order is the intended
sequence. Decisions are in [CLAUDE.md](CLAUDE.md); remove a line in the PR that lands it.

## Fleet plumbing

- [ ] Drop CI's GitHub Actions cache once runs fetching from bastion's Harmonia cache do as well
      without it.
- [ ] Decide whether the laptops substitute from bastion's Harmonia cache.
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
- [ ] UniFi OpenTofu project: the LAN wildcard record made by hand; keep bastion to the camera on
      554 and 2020, and no internet for the
      Cameras VLAN; drop the Home Assistant to IoT media rule.

## Laptops

- [ ] `thinkpad`: host, desktop profile, Stylix, Home Manager, power, backups; persist and back up
      `~/.local/state/infra` (OpenTofu state); a NixOS `remote-builds` with its own builder key, so
      its deploys build on bastion like the mac's; a desktop switcher for the Proton exit nodes,
      on the mac too; an ntfy subscriber for `alerts` on both. The old generation gave every restic repository one password, which the old
      ThinkPad holds and the USB and pCloud repositories still accept: the reinstall must erase it
      (encrypted disk or secure erase), and `restic key add` a fresh `backups/thinkpad-password`
      to the laptop's repository on bastion, removing the old key there, so the new install never
      holds the household key.
- [ ] `asahi`: host (evaluates in CI, builds on itself), desktop profile shared with thinkpad.
- [ ] Operator Home Manager: shell, tmux, neovim, dev tooling, shared across hosts.

## Closing out

- [ ] `ci-deploy`: deploy on merge from GitHub-hosted runners (Tailscale GitHub Action + deploy-rs),
      protected environment with manual approval gated by a path filter on access-changing files;
      its own key on the `deploy` account, which is root-equivalent.
- [ ] Update the `nix` skill placement table once the laptops' desktop modules land.
- [ ] Delete `~/projects/infra-old/` (duplicate) and, when every host runs the new config,
      `infra/infra-old/` and its mention in CLAUDE.md.
