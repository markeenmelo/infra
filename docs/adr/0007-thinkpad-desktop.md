# ADR 0007 — ThinkPad desktop with track-matched Home Manager

- Status: accepted; initial implementation — narrowed by [ADR 0008](0008-native-desktop-and-kernels.md) (desktop-only HM, native modules, Wi-Fi, kernels)
- Date: 2026-09-09

## Context

The user requested Hyprland and Noctalia on ThinkPad — normally Intel graphics and the internal panel, a Samsung display at home, a possible future NVIDIA Thunderbolt eGPU — as a **new** configuration reusing hardware facts but not the old theme, bindings or preferences. Only the Intel GPU/internal panel were observed during discovery; historical eGPU/display references cannot establish a docked configuration.

## Decision

- Compose the desktop capability on ThinkPad instead of `headless`, retaining SSH explicitly (the bundle was later renamed `desktop`; see [ADR 0001](0001-dendritic-composition.md)). The capability spans class-checked deferred NixOS and Home Manager values; Noctalia contributes to the same home value; host/user/display facts stay in the ThinkPad host contribution. Time synchronization and documentation policy moved into base so they do not depend on the session target. Other hosts remain headless.
- Track-matched Home Manager selected alongside the host (`useGlobalPkgs` preserves the host's Nixpkgs, `useUserPackages` uses NixOS-managed profiles), with independent selection and branch/follows assertions in validation. No forwarded flake inputs, package mixing, upstream desktop overlays, standalone home entry points or new cache trust. ThinkPad starts home `stateVersion` at 26.05; it is not an upgrade knob.
- Password-authenticated greetd/tuigreet with UWSM and `start-hyprland`. One session-bound Noctalia service owns the shell, lock/idle/notification/polkit functions; PipeWire, portals and PAM/Secret Service integration belong with the desktop. Where the pinned tracks lack the new Noctalia convenience module, use ordinary HM files/packages/services rather than backporting. Generate Hyprland Lua and Noctalia v5 TOML, checked by each track's native binary.
- A new Noctalia config/state/data profile via its supported environment overrides: no inherited GUI overrides or plugins, no user-state deletion or copying of old desktop preferences, HM file-collision detection retained. Existing durable `/home` needs no duplicate persistence binds.
- Display policy starts conservative: automatic GPU discovery, the observed internal-panel mode, preferred-mode SDR rules for other displays. No unobserved NVIDIA driver, changing card-number pinning, broad Thunderbolt authorization or invented Samsung HDR/VRR/ICC values; docked policy only after hardware verification.

## Consequences

- The desktop is reproducible at file/package/service level without claiming runtime acceptance. GUI overrides created inside the new profile still take precedence and need deliberate reconciliation with declarative choices.
- Existing browser/keyring/application profiles are neither migrated nor erased.

The procedure and acceptance live in [desktop.md](../desktop.md); API pins and the stable-module compatibility decision in [research](../research.md).
