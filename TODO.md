# Rewrite TODO

Remaining work to retire `infra-old/`. One PR per line unless noted; order is the intended
sequence. Decisions are in [CLAUDE.md](CLAUDE.md); check a line off in the PR that lands it.

## Fleet plumbing

- [x] `opentofu`: tailnet policy as HCL, OAuth client and state passphrase carried over, `tofu`
      flake app, encrypted state, `opentofu` skill. Porkbun and UniFi projects follow in their
      own PRs when their consumers land.
- [ ] Tailnet policy: move the literal addresses, services and hosts to fleet facts when bastion
      lands; drop the old fleet's grants, services and proton exit nodes as each host migrates.
      Revisit `group:members` reaching `bastion:443` when the LAN proxy and Authelia land.
- [x] `deploy`: deploy-rs with magic rollback over the tailnet, `deploy` flake app, `deploy` skill.
- [ ] `ci-deploy`: deploy on merge from GitHub-hosted runners (Tailscale GitHub Action + deploy-rs),
      protected environment with manual approval gated by a path filter on access-changing files;
      its own key on the `deploy` account, which is root-equivalent.
- [ ] One NixOS VM test in `nix flake check` (boot, root rollback, `/persist` survives).
- [ ] Build cache for CI and clients: bastion remote builder + Harmonia; decide what CI uses.
      GitHub-hosted arm64 Linux and Apple Silicon macOS runners can build the aarch64 closures
      for it; check the macOS runner's memory against the closures first.
- [ ] Decide the shared password hash on racknerd (per-host `login.yaml` or no password on the edge).

## racknerd

- [x] Edge proxy: Caddy with Porkbun DNS-01 forwarding to bastion over the tailnet.
- [ ] CrowdSec with the firewall bouncer; its user joins the `caddy` group to read the access log.
      Lands before the install, so the portal is never public without bans.
- [ ] Install with nixos-anywhere, `--extra-files` carrying `/persist/etc/ssh` and
      `/persist/var/lib/tailscale`; rotate the auth key first. Manual approval (access change).
- [ ] Porkbun OpenTofu project.

## bastion

- [ ] Host: hardware, disko (OS disk only), data pools as declared mounts, networking, UPS,
      power, LEDs (port only what the hardware needs).
- [ ] LAN proxy (Caddy origin) and Authelia; LLDAP only if Authelia needs it. Each service
      module declares its public route in a `fleet.web.apps` NixOS option; the edge, the LAN
      proxy and the Porkbun records read it from the hub's configuration and the edge literals go.
- [ ] Apps: decide which of the old set stay (Nextcloud stays): Immich, Home Assistant +
      Mosquitto, Frigate, ntfy, SparkyFitness, OpenGym, nixflix (Jellyfin + *arr + downloaders +
      VPN confinement), PostgreSQL shared instance.
- [ ] Monitoring: Prometheus, Loki, Alloy, Grafana dashboards and alerts.
- [ ] Backups: restic to pCloud, restore check.
- [ ] Remote builder + Harmonia cache for the fleet.
- [ ] UniFi OpenTofu project.

## Laptops

- [ ] `thinkpad`: host, desktop profile, Stylix, Home Manager, power, backups; persist and back up
      `~/.local/state/infra` (OpenTofu state).
- [ ] `asahi`: host (evaluates in CI, builds on itself), desktop profile shared with thinkpad.
- [x] `mac`: nix-darwin + Home Manager, Tailscale, shared operator config.
- [x] `mac` apps: Homebrew casks, CLI packages, git, Claude Code.
- [ ] `mac` shell: zsh, starship, tmux, neovim, ghostty and zed settings.
- [ ] `mac` desktop: aerospace, sketchybar, vicinae, `system.defaults`, Stylix, minimal.
- [ ] Operator Home Manager: shell, tmux, neovim, dev tooling, shared across hosts.

## Closing out

- [ ] Remaining skills as their code lands (`opentofu`, `deploy`, `proxy`, `monitoring`,
      `backups`, `desktop`, `darwin`); update `nix` skill placement table.
- [ ] Delete `~/projects/infra-old/` (duplicate) and, when every host runs the new config,
      `infra/infra-old/` and its mention in CLAUDE.md.
