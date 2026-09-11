# ADR 0007 — Fresh ThinkPad desktop with track-matched Home Manager

- Status: accepted; amended by [ADR 0008](0008-native-desktop-and-kernels.md) for native modules, desktop-only HM, requested app reuse, greeter/authentication, Wi-Fi and kernels. The decisions below record the initial implementation.
- Date: 2026-09-09
- Amends [ADR 0005](0005-existing-headless-baseline.md) for ThinkPad's desktop scope and extends [ADR 0002](0002-nixpkgs-tracks.md) to Home Manager

## Context

The user requests Hyprland and Noctalia on ThinkPad, normally using Intel graphics and the internal panel, with a Samsung display at home and a future NVIDIA Thunderbolt eGPU. This must be a new configuration: reuse hardware facts, not the old theme, bindings or preferences. Only the Intel GPU/internal panel were connected during discovery; historical eGPU/display references cannot establish a docked HDR/VRR configuration.

## Decision

Compose a `hyprland` capability on ThinkPad instead of `headless`, retaining SSH explicitly. The later [concern-ownership amendment](0001-dendritic-composition.md#concern-ownership-amendment--2026-09-11) renames the selected bundle `desktop` without changing this session policy. The capability spans class-checked deferred NixOS and Home Manager values; Noctalia contributes to that same home value. Host/user/display facts stay in a contribution to `fleet.hosts.thinkpad.module`. All repository Nix files remain top-level flake-parts modules. Move time synchronization and documentation policy into the existing base so they do not depend on the headless session target. Other hosts remain headless.

Select matching stable-release/unstable-master Home Manager modules at `modules/fleet.nix`, with independent selection and branch/follows assertions in validation. `useGlobalPkgs` preserves each host's own Nixpkgs; `useUserPackages` uses NixOS-managed profiles. No forwarded flake inputs, package mixing, upstream desktop overlays, standalone home entry points or new cache trust. ThinkPad deliberately starts this home configuration at stateVersion 26.05; it is not an upgrade knob.

Use password-authenticated greetd/tuigreet and UWSM with `start-hyprland`. One session-bound Noctalia service supplies the shell, lock/idle/notification/polkit functions. PipeWire, portals and PAM/Secret Service integration belong with the desktop. Neither stable Home Manager nor stable NixOS has the new Noctalia convenience module at these pins; use ordinary HM files/packages/services on both tracks rather than backporting modules. Generate Hyprland Lua and Noctalia v5 TOML, checked by each track's native binary.

Use a new Noctalia config/state/data profile via its supported environment overrides to avoid inheriting old GUI overrides or plugins. Keep Home Manager file-collision detection; no user-state deletion or copying of old desktop preferences. Existing durable `/home` needs no duplicate persistence binds.

Start with automatic GPU discovery, the observed internal-panel mode and conservative preferred-mode SDR rules for other displays. Do not select an unobserved NVIDIA driver, pin changing card numbers, authorize Thunderbolt devices broadly or invent Samsung HDR/VRR/ICC values. Add docked policy only after hardware verification. Keep `fleet.desktop.reviewed = false` pending real login/locking/sleep/portal/audio/mobile review; all existing readiness/storage/access/recovery protections remain.

## Consequences

The desktop is reproducible at the file/package/service level without claiming runtime acceptance. Noctalia GUI overrides created within the new profile still take precedence and need deliberate reconciliation with declarative choices. Existing browser/keyring/application profiles are not migrated or erased by this feature.

Both-track fixtures evaluate HM activation and NixOS toplevel derivations, reject autologin and unreviewed commissioning, and check package/session/profile isolation. Native checks build and parse generated configs on both tracks and the actual ThinkPad composition. They do not boot a compositor, validate password decryption/PAM, test suspend, or certify eGPU/HDR operation. ThinkPad remains local-only and uncommissioned; no standard host build/deploy output is exposed early.

The [desktop procedure](../desktop.md) records new defaults, bindings, state ownership and target acceptance. API pins and the stable-module compatibility decision are in [research](../research.md).
