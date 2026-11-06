# Rewrite TODO

Remaining work to retire `infra-old/`. One PR per line unless noted; order is the intended
sequence. Decisions are in [CLAUDE.md](CLAUDE.md); remove a line in the PR that lands it.

## Fleet plumbing

- [ ] Tailnet policy: move the literal addresses, services and hosts to fleet facts when bastion
      lands; drop the old fleet's grants, services and proton exit nodes as each host migrates,
      and the `sparkyfitness` and `opengym` services and `member_services`.
      Revisit `group:members` reaching `bastion:443` now that the LAN proxy and Authelia landed.
- [ ] One NixOS VM test in `nix flake check` (boot, root rollback, `/persist` survives).
- [ ] Build cache for CI and clients: bastion remote builder + Harmonia; decide what CI uses.
      GitHub-hosted arm64 Linux and Apple Silicon macOS runners can build the aarch64 closures
      for it; check the macOS runner's memory against the closures first.
- [ ] Decide the shared password hash on racknerd (per-host `login.yaml` or no password on the edge).

## bastion

- [ ] Front-panel LEDs (out-of-tree `led-ugreen` driver, disk presence and link).
- [ ] Each service module declares its public route in a `fleet.web.apps` NixOS option; the edge
      and the LAN proxy read it from the hub's configuration and the edge literals go, including
      the Home Assistant route and the Nextcloud denials. The first forward-auth route widens
      Authelia's session cookie from `auth.` to the parent domain.
- [ ] Apps, one PR each: Immich, Frigate, ntfy, OpenCloud replacing Nextcloud, nixflix (Jellyfin +
      *arr + downloaders + VPN confinement). Dropped: Home Assistant, Mosquitto, SparkyFitness,
      OpenGym; their databases in the old PostgreSQL cluster are dropped by hand after the install.
      - Frigate: OpenVINO on the iGPU, with person object filters (`min_area`, ratios,
        `threshold`) and zone `inertia` against false positives; the operator tunes the values.
        MQTT off, since nothing consumes it. The Tapo C120 is `192.168.3.2` on the Cameras VLAN
        (RTSP 554, ONVIF 2020), which bastion's firewall does not block.
      - OpenCloud on `opencloud-production`, files only (not oCIS: nixpkgs has only an old unfree
        binary). State on a new `tank/opencloud` dataset; `/etc/opencloud/opencloud.yaml` holds
        generated secrets, so persist it or render it from sops. Authelia becomes its OIDC
        provider with public PKCE clients and a role claim, so the users file gains groups.
        Files move with `rclone copy` from `/srv/nextcloud/instance/data/USER/files` over WebDAV
        (shares, links, versions and trash do not carry over); check `tank` free space first,
        then destroy `tank/nextcloud` and drop its mount and snapshots.
- [ ] Monitoring: Prometheus, Loki, Alloy, Grafana dashboards and alerts.
- [ ] Backups: restic to pCloud, restore check, PostgreSQL dumps.
- [ ] Remote builder + Harmonia cache for the fleet.
- [ ] Install bastion once the household apps are ported: the install replaces every running
      service. Carries the identity, sbctl and ZFS keys.
- [ ] LAN wildcard record on the UniFi gateway, by hand until the UniFi project lands.
- [ ] UniFi OpenTofu project: keep bastion to the camera on 554 and 2020, and no internet for the
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
- [ ] Remaining skills as their code lands (`monitoring`, `backups`, `desktop`); update `nix`
      skill placement table.
- [ ] Delete `~/projects/infra-old/` (duplicate) and, when every host runs the new config,
      `infra/infra-old/` and its mention in CLAUDE.md.
