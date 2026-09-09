---
name: add-host
description: Add a NixOS fleet member with explicit architecture and stable or unstable track, dendritic capability composition, safe hardware/storage facts and deployment readiness.
---

# Add a host

## Purpose / when

Add a new identity without copying another machine's facts or silently inheriting its release track.

## Prerequisites

Read `../../../AGENTS.md`, `../../../modules/fleet.nix`, `../../../modules/validation.nix`, and `../../../docs/bootstrap.md`. Obtain the intended role, architecture and explicit track decision. Missing physical facts are allowed only as uncommissioned blockers. Invoke `nix-research` for new hardware/provider/APIs or release choices.

## Procedure

1. Create a small top-level module under `modules/` defining `fleet.hosts.<name>` with **required** `system`, `track` and `capabilities`. Use a simple lowercase hostname. Names/path placement never choose a track. Do not copy a complete existing host file.
2. Intentionally select `stable` for conservative service operation or `unstable` for the requested interactive policy. The existing fleet's policy stays unchanged. Extend the independent `expectedTracks` oracle in `modules/validation.nix` with the same reviewed intent.
3. Compose existing capabilities. Current host reports/checks expect OS disk, persistence and access; the evaluator adds base. If a genuinely different storage strategy is required, research and implement it rather than supplying fake device data. For a new architecture, first extend the typed schema, build/test platform coverage and CI; current support is x86_64-linux only.
4. Keep `ready = false`. Adapt an actual hardware scan into `fleet.hosts.<name>.module` in a hardware-focused **top-level** file; do not import a raw generated lower-level repository file. Separate storage assignments, users and networking by concern. Never borrow UUIDs/devices/GPUs/NICs from another host.
5. Set the original or deliberately chosen initial `fleet.installation.stateVersion`; verify hardware/initrd/firmware/network/provider/console requirements before setting review flags. Do not tie stateVersion to track updates.
6. Follow `storage-disko` for OS disk identity/confirmation/firmware/ESP decisions and data-disk exclusion. Follow `impermanence` for identity, SSH, user/service state and migration. Do not assume user data on an ephemeral server home is durable.
7. Configure real admin public keys, runtime credentials and elevation. Configure interactive users separately from the admin. Resolve desktop/gaming/NAS/VPS-specific review requirements only after actual decisions.
8. Define `fleet.hosts.<name>.deployment` independently: enable policy, nullable address until known, SSH account/port, activation/elevation, closure trust, timeouts and remote-build policy. Intermittently online hosts should be opt-in. No DNS/IP guesswork.
9. `git add` intended new files, run `just fmt`, `just check`, then inspect `nix eval --json .#fleet.<name>`. Document the identity/composition in README. Fix all unexpected assertions; known missing facts must remain explicit.
10. Only after commissioning review, set `ready = true`, rerun `just check`, `just ready <name>` and `just build <name>`. Use the bootstrap runbook for separately authorized installation and acceptance testing; adding a host never authorizes deployment.

## Completion criteria

The new host is explicitly tracked and validated, uses only reviewed capabilities/facts, and either passes readiness/build or clearly remains uncommissioned. Report which facts remain missing and which track/revision actually evaluates it.

## Common failures / safety

Untracked files are invisible to Git flakes; wrong capability names fail evaluation; an unchanged policy oracle rejects new identities. A ready flag does not fix missing facts. Never bypass assertions, copy fixture sentinels, provision unknown disks, or upgrade another host while adding this one.
