---
name: desktop
description: The ThinkPad desktop — Hyprland/Noctalia session, Home Manager bridge, displays, authentication and agent configuration. Use when changing anything under modules/desktop/.
---

# ThinkPad desktop

The desktop is ThinkPad-only and unstable-only. `modules/desktop.nix` owns the Home Manager bridge: it imports the HM NixOS module, feeds `flake.modules.homeManager.desktop` into `home-manager.sharedModules` with `useGlobalPkgs`/`useUserPackages`, and asserts at import time that the evaluation is on the unstable track. Servers stay headless and never import HM.

Work in the concern's own file under `modules/desktop/`. There is no `scripts/` tree: an executable helper is built in Nix with `pkgs.writeShellApplication` (or equivalent) inside the module that owns it, and nothing tests it.

## What to preserve

1. **One owner per role.** One UWSM session owner, one shell, one locker, one polkit agent, one notification service. Two of anything here is a bug, not a fallback.
2. **Authentication.** Fingerprint is an alternative to a nonempty password, never a way to authenticate an empty one, and it does not unlock the keyring. Greetd autologin is rejected by assertion. Keep the private AccountsService mode override — upstream re-enforces `0775` on service start otherwise.
3. **Displays.** `modules/desktop/displays.nix` now declares static Hyprland `monitor` rules only: connector-independent `preferred` at `auto-center-up`, with the internal `eDP-1` panel anchored at `0x0`, scale 1. The runtime output policy — external-display detection, EDID-gated HDR, lid-switch response and the socket watcher — was removed, so a docked or lid-closed ThinkPad is now Hyprland's default behaviour, not ours. Never hardcode external connector names or pixel offsets in the static rules. Real modesetting is still not a check.
4. **Wi-Fi.** Declarative credentials were removed: `modules/desktop/wifi.nix` sets powersave and group membership only. Profiles are created by hand and survive in the persisted `/etc/NetworkManager/system-connections`. The encrypted PSK and campus credentials remain in `secrets/` but are unselected. Never put a credential back into Nix, never log one, and never relax CA or name validation.
5. **Packages and state.** Use the host's own `pkgs`. Keep upstream serialization and collision detection, the isolated Noctalia profile, zoxide initialized after Starship, the two targeted duplicate-autostart masks, and manual browser-export imports. Zen keeps the Firefox wrapper passthru adapter and `normal_installed` extensions so pinned updates survive. Do not copy private application state into the store or make store-backed settings writable.
6. **Agents.** Pi's extensions are pinned `npm:` specs in its managed settings — mutable private home state. Keep project trust set to ask.

## Checking

Run `nix fmt`, then `nix build --no-update-lock-file --no-link .#nixosConfigurations.thinkpad.config.system.build.toplevel`. That establishes evaluation and closure construction only — the generated-config validators (`hyprland --verify-config`, Noctalia, Ghostty, herdr) no longer run anywhere, so a malformed generated config now surfaces at login instead.

ThinkPad's fresh candidate is `ready = false` and local-only. Readiness no longer gates evaluation, so it builds like any other host — that is not commissioning. Never set it ready, and never activate the fresh layout over the running installation. Login, graphical, peripheral, printer, network and boot behaviour all need separate authorization and real hardware.
