# infra

The whole configuration of a one-operator home fleet: the NixOS hosts, the mac on nix-darwin, the
Tailscale, Porkbun and UniFi setup in OpenTofu, and their secrets as SOPS ciphertext. It is public
to be read; nothing here is meant to be reused as is.

## Layout

- `flake.nix` holds only inputs and imports every file under [`modules/`](modules/) with
  flake-parts and import-tree. Each file is one concern and sets every class it touches: NixOS,
  nix-darwin and Home Manager.
- [`modules/hosts/`](modules/hosts/): each host's facts, hardware, disk layout and the roles it
  imports.
- [`opentofu/`](opentofu/): the Tailscale policy, the public DNS records and the UniFi network.
- [`secrets/`](secrets/): SOPS files, ciphertext only; [`.sops.yaml`](.sops.yaml) names who
  can decrypt each.
- [`.claude/skills/`](.claude/skills/): how each part works and the rules it follows, one skill
  per area. [CLAUDE.md](CLAUDE.md) lists the hosts and the decided stack.

## Working on it

The dev shell (direnv) provides `just`, `sops` and the formatter. `just` lists the tasks; each
wraps a flake app or a Nix command:

```sh
just check            # evaluate every host
just deploy bastion   # activate this checkout on bastion over the tailnet
just tofu unifi plan  # plan an OpenTofu project
```

CI builds every x86_64 host on each pull request and on `main`; review bots read every diff.
`gh workflow run audit.yml` audits the whole tree on demand and writes the report to the run's
summary.

## Security

See [SECURITY.md](SECURITY.md) for what is in scope and how to report a vulnerability.
