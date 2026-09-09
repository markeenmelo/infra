# Operations

Run commands from the repository root inside `nix develop --no-update-lock-file`. Consult the matching `.agents/skills/` procedure and [research ledger](research.md) before changing dependency-sensitive APIs.

## Input updates

Never substitute `system.stateVersion` for the current supported release. It is a state migration boundary, not an update knob.

1. Start with a reviewed clean working tree and save the current lock:
   ```sh
   before=$(mktemp)
   cp flake.lock "$before"
   ```
2. Research affected upstream changes. For stable, determine whether the current branch is still supported and review stable/security/service release notes. For unstable, inspect significant NixOS/module/driver changes since the locked revision. For full updates, include unstable Home Manager, the pinned Zen recipe, disko, impermanence, sops-nix, deploy-rs and flake-parts issues. Desktop updates must review the actual target-packaged Hyprland/Noctalia APIs and new profile behavior, not legacy Noctalia Shell 4.x instructions. SOPS currently has an explicit reused revision in `flake.nix`; advancing it requires a researched URL revision edit, not just `nix flake update`.
3. Choose **one** update scope:
   ```sh
   nix flake update nixpkgs-stable
   # OR
   nix flake update nixpkgs-unstable
   # OR
   nix flake update
   ```
4. Run `just check` for every scope (the fleet is small). Pay special attention to `racknerd`/`bastion` for stable, `thinkpad`/`dino` for unstable. For commissioned targets build their system closures with `just build HOST`. No deployment is implied.
5. Review **every** changed lock node:
   ```sh
   jq -n --slurpfile old "$before" --slurpfile new flake.lock '
     ($old[0].nodes + $new[0].nodes | keys[]) as $k |
     select($old[0].nodes[$k].locked != $new[0].nodes[$k].locked) |
     {input: $k, before: $old[0].nodes[$k].locked, after: $new[0].nodes[$k].locked}'
   git diff -- flake.nix flake.lock
   ```
   Targeted updates must not move the other fleet track or unrelated dependency pins. A dependency following stable uses the new stable packages without changing its own source revision; report this too. Commit only the intended update and compatibility fixes with exact before/after revisions.

Inspect locked branch/revision/hash without evaluating a machine:

```sh
jq '.nodes as $n | ["nixpkgs-stable", "nixpkgs-unstable"][] as $i |
  {input:$i, original:$n[$n.root.inputs[$i]].original, locked:$n[$n.root.inputs[$i]].locked}' flake.lock
```

Only the unstable desktop uses Home Manager. The input is named `home-manager`, with URL `github:nix-community/home-manager`. Update it independently with `nix flake update home-manager`; validate the unstable desktop/actual ThinkPad configs and all both-track infrastructure checks. Updating unstable Nixpkgs changes HM's packages without moving HM's source revision; stable updates have no HM dependency.

Zen is a normal `zen-browser` flake input with URL `github:youwen5/zen-browser-flake` and an unstable follows link. Both Zen and Home Manager use default-branch URLs; exact revisions live only in `flake.lock`. A scoped Zen update uses `nix flake update zen-browser`, with review of its recipe/wrapper adapter and extension XPI pins. Continue passing the consuming host's `pkgs` into the recipe instead of importing upstream's separately instantiated package outputs. Validation checks input identity, flake status and follows policy, not a hardcoded Zen commit. Pi's extension manifest/lock, npm hash, pi-review revision and small compatibility patch are separately pinned; update and test them together, without credentials or provider settings drift. Preserve HM file-collision checks and the isolated Noctalia profile. See [desktop ownership](desktop.md).

Every host uses its track's latest **stock 7.x** kernel. Check kernel EOL/release changes and Bastion's actual `kernelPackages.${boot.zfs.package.kernelModuleAttribute}` derivation. Never use the removed `.zfs` alias, allow broken packages, mix tracks or silently cross the major-version guard. Preserve recovery generations/ESP headroom and arrange boot/pool acceptance separately; a compatible derivation is not a tested boot.

A **stable release migration** changes the numbered stable Nixpkgs URL in `flake.nix` after fresh research, then updates that input; there is no stable HM URL to maintain. Do not automatically jump servers to a new release or bump their stateVersion. Update the dated research record and validate database/service compatibility and restores.

## ThinkPad Nix Helper (nh)

`modules/nh.nix` enables native NixOS `programs.nh` **only on ThinkPad**, using its own `pkgs.nh` (currently 4.4.2). `programs.nh.flake = "/home/marcos/projects/infra"` sets **`NH_FLAKE`** at this Nixpkgs pin. This is the observed checkout path, not a store copy or guessed server path. An explicit installable or `NH_OS_FLAKE` can override it; update the declaration if the checkout moves. Settings take effect during a separately authorized activation, not by editing this repository.

`programs.nh.clean.enable = false`: no nh cleanup service/timer, generation pruning, automatic input updates or rebuild aliases. Keep recovery generations and use the reviewed input-update procedure above. Home Manager is integrated into NixOS; there is no standalone output for `nh home`.

`just check` remains canonical and `just ready thinkpad` must still pass before a system build. **After genuine commissioning**, a build-only helper invocation is:

```sh
just check
just ready thinkpad
nh os build --hostname thinkpad --no-update-lock-file
```

This cannot select the currently uncommissioned ThinkPad from `nixosConfigurations`. Do not bypass that gate, validation or input review with helper flags. `nh os switch`, `test`, `boot`, remote target/build options and `nh clean` require their own operation authorization; none was executed here. Smoke tests run only `nh --version` and `nh os build --help`, not rebuilds or activation.

## Deployment and recovery

All four hosts are already installed; follow the [baseline transition checklist](hosts.md) before commissioning. Their disko provisioning outputs are disabled, including `disk-plan`; [bootstrap's installation section](bootstrap.md#storage-and-installation) is fresh-install-only. deploy-rs assumes NixOS, reachable non-root SSH, working elevation and closure trust already exist. Servers currently have root-only access, so a separate staged access transition is required. Baseline removes Tailscale: validate alternate routing/recovery before activation.

### Preflight

1. `just check`; inspect `just inventory` and `nix eval --json .#deploymentPlan | jq .`.
2. Use `bash scripts/ready.sh HOST deploy` for deployment-specific readiness, or `just ready HOST` for build readiness. `just deploy HOST` performs the deploy-specific preflight automatically. The SSH user must be non-root with configured public keys; root is rejected to match the SSH root-login restriction. Keep the system activation `profileUser` as root and verify the chosen elevation path.
3. Confirm the reported revision/actual package source matches the independent host policy. Check a known-good generation and backup/restore status. The persistent SOPS identity, intended ciphertext/recipients and early-decryption path must be verified, alongside signing keys; pure checks cannot verify them. SOPS creates runtime password files during activation, not during builds. Follow the [secret procedure](../secrets/README.md).
4. Verify host-key fingerprint, reachability, free `/nix`/`/boot` space, admin login, sudo/doas policy and Nix closure trust. Do not put credentials in flake arguments, source files or shell history. For signed transport, securely set `LOCAL_KEY` to the existing signing-key path; the target must already trust its public key.
5. Keep an independent console and an existing SSH session open for sensitive changes. Consider `--dry-activate` only after authorization: it still contacts/copies to the target and is **not** a purely local check.

### Commands (these really deploy)

```sh
just deploy racknerd

# Subset: manually preflight each; --targets is the verified upstream API.
just check
bash scripts/ready.sh racknerd deploy
bash scripts/ready.sh bastion deploy
deploy --targets .#racknerd .#bastion -- --no-update-lock-file

# All currently commissioned and enabled nodes; refuses an empty set.
just deploy-fleet
```

`deploy .` means all **eligible** nodes, not all four identities. Dino now has explicit deployment intent but remains unready; thinkpad remains local-only. To include another offline workstation, explicitly set `fleet.hosts.<name>.deployment.enable = true`, supply metadata/SSH/trust and commission it. Otherwise build/switch locally after authorization. Prefer a named subset for intermittently online targets; an offline desktop is not a reason to remove rollback safeguards.

deploy-rs builds from the locked input. Its default own checks may evaluate/build **all** eligible nodes even when a subset is selected; our `just check` also covers the full fleet. This costs more once real machines are commissioned but does not contact them. `remoteBuild` moves the build to the target only when selected; review resources and trust before enabling it.

### Rollback semantics

- `autoRollback = true`: return to the previous profile if activation fails.
- `magicRollback = true`: target rolls back if the client does not confirm post-activation reachability in time. Default confirmation is 60 seconds, activation 300 seconds, with SSH liveness limits.
- In a multi-target invocation, successful earlier profiles can also roll back if a later one fails. The verified override `--rollback-succeeded false` changes that policy; use only deliberately.
- None of these revert database migrations, `/persist`, user/NAS data, partition changes or secrets. None guarantee the next reboot succeeds.

When a host is unreachable, stop. Check power/network/rescue console and wait for pending rollback to settle. Do not retry blindly, disable magic rollback, delete known_hosts entries, or format disks. An SSH fingerprint change must be explained before accepting a new key.

**SSH-changing deployments:** prefer a two-stage migration keeping old and new access working until separately tested. Port/IP changes can cause the confirmation connection to fail and trigger rollback. If an access-breaking change is unavoidable, use a console and a planned maintenance window. Only with explicit authorization might an operator use:

```sh
deploy .#racknerd --magic-rollback false -- --no-update-lock-file
```

This disables the reachability safety mechanism; automatic activation-failure rollback is still on. `deploy .#racknerd --auto-rollback false` is a separate, usually inappropriate override. Neither belongs in repository defaults. Check the **locked** `deploy --help` before relying on flag syntax after updates. `--test` activates without setting boot defaults; `--boot` updates boot selection without a live switch, and therefore requires a reboot plan.

From a real target's console, a standard manual generation recovery is:

```sh
sudo nixos-rebuild switch --rollback
```

Or select the previous generation in its bootloader. Inspect the result before reconnecting/deploying again. Do not prune old generations automatically; maintain a deliberate retention policy and monitor disk space. If a service has migrated on-disk formats, restoring its data may be necessary even after reverting NixOS.

## Persistence, observability and backups

`just inventory` lists declared persistent paths. New services must define ownership/mode and state requirements next to their configuration, ideally with a mount dependency so they cannot write into an ephemeral placeholder when their durable filesystem is missing. State outside declared paths is lost at reboot. State deliberately written directly into `/persist` remains even if not listed in the bind-mount inventory.

Servers retain a bounded journal; interactive hosts use volatile logs. No monitoring endpoint, exporter, application database, NAS share, unattended backup or automatic garbage collection is silently enabled. Racknerd's fail2ban database persists; bastion retains its observed monthly `tank` scrub schedule, which is not a backup. Before production services, add separately reviewed backup/restore and observability features with runtime credentials and tested failure handling. A Btrfs subvolume and a persistent root policy are **not backups**. Removing an impermanence declaration leaves backing data; inspect it, do not automatically delete it.

Recommended future work, not implemented here: review dino's unencrypted storage and boot filesystem, complete per-host SOPS identity/credential provisioning and acceptance, VPN access, ThinkPad's hardware-verified NVIDIA/Samsung HDR/VRR profile and desktop runtime acceptance, optional Dino desktop/gaming capabilities, service-specific backups with restore exercises, and QEMU/real-hardware reboot tests. Thinkpad's existing LUKS encryption is preserved, not newly provisioned. Add only what the fleet actually needs.
