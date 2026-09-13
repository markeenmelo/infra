---
name: desktop
description: The ThinkPad desktop — Hyprland/Noctalia session, Home Manager bridge, displays, Wi-Fi credentials, authentication and agent configuration. Use when changing anything under modules/desktop/ or modules/agents/.
---

# ThinkPad desktop

The desktop is ThinkPad-only and unstable-only. `modules/desktop.nix` owns the Home Manager bridge: it imports the HM NixOS module, feeds `flake.modules.homeManager.desktop` into `home-manager.sharedModules` with `useGlobalPkgs`/`useUserPackages`, and asserts at import time that the evaluation is on the unstable track. Servers stay headless and never import HM.

Work in the concern's own file under `modules/desktop/` (or `modules/agents/`), together with its checks. Executable helpers and their tests live in `scripts/desktop/`.

## What to preserve

1. **One owner per role.** One UWSM session owner, one shell, one locker, one polkit agent, one notification service. Two of anything here is a bug, not a fallback.
2. **Authentication.** Fingerprint is an alternative to a nonempty password, never a way to authenticate an empty one, and it does not unlock the keyring. Greetd autologin is rejected by assertion. Keep the private AccountsService mode override — upstream re-enforces `0775` on service start otherwise.
3. **Displays.** Use native `preferred` mode and `auto-center-up` at scale 1 with the internal panel anchored at `0x0`. Never infer the preferred mode from `availableModes[0]`, never hardcode external connector names or pixel offsets. Keep physical DRM eligibility, EDID-gated HDR, the exact Lua acknowledgement, subscriber-first sync and the fresh active-external check before disabling the panel. Propagate parsing, command and socket errors instead of guessing a topology. Real modesetting is not a check.
4. **Wi-Fi.** The PSK and campus credentials come from SOPS into root-only runtime NetworkManager profiles through the environment adapter. Preserve both systemd and GLib escaping, reject placeholder markers, never emit partial output, never log a value and never relax CA or name validation.
5. **Packages and state.** Use the host's own `pkgs`. Keep upstream serialization and collision detection, the isolated Noctalia profile, zoxide initialized after Starship, the two targeted duplicate-autostart masks, and manual browser-export imports. Zen keeps the Firefox wrapper passthru adapter and `normal_installed` extensions so pinned updates survive. Do not copy private application state into the store or make store-backed settings writable.
6. **Agents.** Pi's extensions are pinned `npm:` specs in its managed settings — mutable private home state, never installed during a check. Keep project trust set to ask.

## Checking

Run the validation sequence in [devenv](../devenv/SKILL.md). Source and generated-config tests are the only thing they establish.

ThinkPad's fresh candidate is `ready = false` and local-only; inspect it through `fleetConfigurations`. Never set it ready to obtain a build, and never activate the fresh layout over the running installation. Login, graphical, peripheral, printer, network and boot behaviour all need separate authorization and real hardware.
