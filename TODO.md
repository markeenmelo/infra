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
- [ ] Decide the shared password hash on racknerd (per-host `login.yaml` or no password on the edge).

## racknerd

- [ ] Install with nixos-anywhere, `--extra-files` carrying `/persist/etc/ssh` and
      `/persist/var/lib/tailscale`; rotate the auth key first. Manual approval (access change).
- [ ] Edge proxy: Caddy with Porkbun DNS-01 forwarding to bastion over the tailnet; Porkbun
      OpenTofu project and `pk1_`/`sk1_` pattern in the secrets scan land here.
- [ ] CrowdSec with the firewall bouncer.

## bastion

- [ ] Host: hardware, disko (OS disk only), data pools as declared mounts, networking, UPS,
      power, LEDs (port only what the hardware needs).
- [ ] LAN proxy (Caddy origin) and Authelia; LLDAP only if Authelia needs it.
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
- [ ] `mac`: nix-darwin + Home Manager, Tailscale, shared operator config.
- [ ] Operator Home Manager: shell, tmux, neovim, dev tooling, shared across hosts.

## Closing out

- [ ] Review ruleset: keep or drop "threads must be resolved".
- [ ] Remaining skills as their code lands (`opentofu`, `deploy`, `proxy`, `monitoring`,
      `backups`, `desktop`, `darwin`); update `nix` skill placement table.
- [ ] Delete `~/projects/infra-old/` (duplicate) and, when every host runs the new config,
      `infra/infra-old/` and its mention in CLAUDE.md.
