# infra

The whole configuration of a one-operator home fleet: the NixOS hosts, the mac on nix-darwin, the
Tailscale, Porkbun, UniFi and Oracle Cloud setup in OpenTofu, and their secrets as SOPS ciphertext. It is public
to be read; nothing here is meant to be reused as is.

## Hosts

| Host | System | Role | Builds on |
|---|---|---|---|
| `bastion` | x86_64-linux | Home server: LAN and public proxy, identity, apps, storage, monitoring, backups, remote builder, Harmonia cache, agent MicroVM | itself |
| `edge` | aarch64-linux | Public HTTPS edge (Oracle Cloud instance): passes TLS through to bastion unread; encrypted, unlocked over SSH | itself |
| `thinkpad` | x86_64-linux | Operator laptop | bastion |
| `asahi` | aarch64-linux | Apple Silicon laptop (dual boot with `mac`) | itself |
| `mac` | aarch64-darwin | macOS laptop, nix-darwin + Home Manager | itself |

## Quick start

The dev shell provides `just`, `sops`, `openssl`, `mkpasswd`, `jq` and the formatter. `just` lists the tasks; each wraps a
flake app or a Nix command:

```sh
direnv allow          # or: nix develop
just                  # list every task
just check            # evaluate every host and every check, building nothing
just fmt              # format every file
just switch           # switch the laptop you are on to this checkout
just deploy bastion   # activate the committed checkout on bastion over the tailnet
just tofu unifi plan  # plan an OpenTofu project
```

## Layout

- `flake.nix` holds only inputs and imports every file under [`modules/`](modules/) with
  flake-parts and import-tree. Each file is one concern and sets every class it touches: NixOS,
  nix-darwin and Home Manager. Importing a module enables it; there are no `enable` options.
- [`modules/hosts/`](modules/hosts/): each host's facts, hardware, disk layout and the roles it
  imports.
- [`opentofu/`](opentofu/): the Tailscale policy, the public DNS records, the UniFi network and the
  Oracle Cloud instances.
- [`secrets/`](secrets/): SOPS files, ciphertext only; [`.sops.yaml`](.sops.yaml) names who
  can decrypt each.
- [`.claude/skills/`](.claude/skills/): how each part works and the rules it follows, one skill
  per area; the [nix skill](.claude/skills/nix/SKILL.md) says where a module, option, package pin,
  app or check goes. [CLAUDE.md](CLAUDE.md) holds the agents' rules and the decided stack.
  [TODO.md](TODO.md) lists the work to come.

Flakes see only files Git tracks, so `git add` a new file before evaluating.

## Secrets

Only ciphertext is committed. The operator decrypts with the age key in
`~/.config/sops/age/keys.txt`, each host with its SSH host key; `.sops.yaml` has one exact rule per
file.

```sh
sops edit secrets/hosts/HOST.yaml              # change values
sops updatekeys -y secrets/shared/login.yaml   # after a .sops.yaml rule change
```

A unit's secret is declared as `sops.secrets.NAME` beside the unit that reads it, in the same
commit as the ciphertext. The `secrets` check fails on plaintext or on recipients that differ from
the rule. Which file holds which key, delivery and rotation: the
[secrets skill](.claude/skills/secrets/SKILL.md).

## Deploying

Every NixOS host is a deploy-rs node reached over the tailnet as the `deploy` account, with magic
rollback: an activation that breaks the SSH path reverts by itself. The app refuses uncommitted
tracked changes.

```sh
just deploy HOST           # activate the committed checkout
just deploy HOST --boot    # set the boot default only; no rollback
just reboot HOST
just deploy-many A B       # concurrent builds, sequential activations
just unlock edge           # send the disk passphrase to the edge waiting in its initrd
just switch                # the mac and the laptops switch themselves
```

Who builds what, the deploy account and recovery: the [deploy skill](.claude/skills/deploy/SKILL.md).

## Bootstrap

A host's first activation is a nixos-anywhere install from an installer image, not a deploy. It
wipes the disk, and it carries the host's SSH and tailnet identity so sops-nix decrypts on first
boot.

```sh
just enroll HOST                          # a new host: make its identity on this machine
just install HOST USER@ADDRESS IDENTITY   # a new host, with the directory enroll named
just install HOST root@ADDRESS /mnt/old/persist   # a reinstall, identity carried off the old disk
```

The steps around these commands: the [deploy skill](.claude/skills/deploy/SKILL.md#install); each
host's own skill covers its hardware (the [edge](.claude/skills/edge/SKILL.md) also resizes its
instance for the install).

## Adding a host or a system

1. Give the host a tag in `enrollment` in [opentofu/tailscale](opentofu/tailscale/main.tf) and
   apply, which mints its tailnet key ([opentofu skill](.claude/skills/opentofu/SKILL.md)).
2. `just enroll HOST` prints the three facts its configuration needs: the age recipient, the
   tailnet address and the initrd host key.
3. Add the recipient and a `hosts/HOST.yaml` rule to `.sops.yaml`
   ([secrets skill](.claude/skills/secrets/SKILL.md#new-host)), then create the file with the
   `tailscale-auth-key` every NixOS host declares
   ([tailnet skill](.claude/skills/tailnet/SKILL.md#auth-key)). The key `enroll` spent will do,
   since it is ignored once the node is logged in, but it is no fallback if the host rejects its
   enrolled login on first boot: rotate the key first to have one
   ([deploy skill](.claude/skills/deploy/SKILL.md#install)).
4. Write `modules/hosts/HOST/`: `host.nix` (facts and the roles it imports), `hardware.nix` and
   `disko.nix`, `git add` them, and `just check`.
5. Install as in [Bootstrap](#bootstrap), add the host to the table above, and delete the identity
   directory once it answers on the tailnet.

A new system is a value in `systems` ([flake-parts.nix](modules/flake-parts.nix)) and in the
`system` type ([fleet.nix](modules/fleet.nix)). A host whose system bastion cannot build builds
itself, and CI builds it only once [check.yml](.github/workflows/check.yml) has a runner for it.

## CI

[check.yml](.github/workflows/check.yml) evaluates every system and builds the x86_64 hosts and
the mac on `main`; a pull request builds only the checks whose derivation differs from its base
commit's, which `main`'s run covers. The aarch64-linux hosts (`edge`, `asahi`) are
evaluated, not built. Review bots read every diff. `gh workflow run audit.yml` audits the whole
tree on demand and writes the report to the run's summary.

## Security

See [SECURITY.md](SECURITY.md) for what is in scope and how to report a vulnerability.
