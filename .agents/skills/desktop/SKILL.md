---
name: desktop
description: The ThinkPad desktop — Hyprland/Noctalia session, Home Manager bridge, displays, authentication and agent configuration. Use when changing anything under modules/desktop/.
---

# ThinkPad desktop

The desktop is ThinkPad-only and unstable-only. `modules/desktop.nix` owns the Home Manager bridge: it imports the HM NixOS module, feeds `flake.modules.homeManager.desktop` into `home-manager.sharedModules` with `useGlobalPkgs`/`useUserPackages`, and asserts at import time that the evaluation is on the unstable track. `modules/hosts/thinkpad/host.nix` explicitly enrolls Marcos in Home Manager, independently of display and Git settings. Servers stay headless and never import HM.

Work in the concern's own file under `modules/desktop/`. There is no `scripts/` tree: an executable helper is built in Nix with `pkgs.writeShellApplication` (or equivalent) inside the module that owns it, and nothing tests it.

## What to preserve

1. **One owner per role.** One UWSM session owner, one shell, one locker, one polkit agent, one notification service. Two of anything here is a bug, not a fallback.
2. **Authentication.** Fingerprint is an alternative to a nonempty password, never a way to authenticate an empty one, and it does not unlock the keyring. Greetd autologin is rejected by assertion. Keep the private AccountsService mode override — upstream re-enforces `0775` on service start otherwise.
3. **Displays.** Static Hyprland `monitor` rules use automatic `highres` selection: `modules/desktop/hyprland.nix` owns the connector-independent default at `auto-center-up`; `modules/desktop/displays.nix` anchors the internal `eDP-1` panel at `0x0` and matches the Samsung Odyssey G93SC by description with `maxwidth`. That exception prioritizes its full-width 5120×1440 mode (advertised at 60 Hz on the current connection) over competing 3840×2160 modes, without fixing a refresh rate. All rules retain scale 1, sRGB SDR, 8-bit color and VRR off. There is no custom runtime panel/lid policy; logind uses its default lid handling. Never add a second suspension owner or inhibit logind's lid handling. Never hardcode external connector names or pixel offsets in the static rules. Real modesetting is still not a check.
4. **Wi-Fi.** `modules/desktop/networkmanager.nix` owns NetworkManager, administrator group membership, persistence and the Home Manager applet/autostart mask. ThinkPad enables NetworkManager's native `wifi.powersave`; TLP is not enabled. Declarative credentials remain removed. Profiles are created by hand and survive in the persisted `/etc/NetworkManager/system-connections`. The encrypted PSK and campus credentials remain in `secrets/` but are unselected. Never put a credential back into Nix, never log one, and never relax CA or name validation.
5. **Packages and state.** Use the host's own `pkgs`. Keep upstream serialization and collision detection, the isolated Noctalia profile, zoxide initialized after Starship, the two targeted duplicate-autostart masks, and manual browser-export imports. Zen keeps the Firefox wrapper passthru adapter and `normal_installed` extensions so pinned updates survive. `modules/desktop/git.nix` enables Git for the desktop but targets the existing personal identity only at Marcos. Do not copy private application state into the store or make store-backed settings writable.
6. **Agents.** Pi's extensions are pinned `npm:` specs in its managed settings, without managed extension defaults. Keep the pinned set and Pi's OpenAI Codex provider, model, thinking level and changelog settings, and keep project trust set to ask. Standalone Claude Code uses the pinned Ponytail plugin with `opus`, `xhigh` effort and plan-mode permissions. Keep Node.js shared through the Home Manager profile. Never enable permission bypasses, extension-specific defaults or Cursor wiring.

## Power and charging

`modules/laptop.nix` enables Power Profiles Daemon and UPower, preserving PPD, backlight and rfkill state. ThinkPad restores its prior thermald enablement without bypassing its platform check. `modules/hosts/thinkpad/laptop.nix` sets UPower's native BAT0 hwdb `CHARGE_LIMIT=85,90` and seeds its `charging-threshold-status` with exactly `1` before each UPower start. UPower applies the limits; no TLP or extra daemon is needed. UPower's D-Bus control can temporarily disable them; they return at the next UPower start. Do not persist that enable/disable state. Keep the 300-second lock, 360-second screen-off and no automatic idle suspend unchanged.

After separately authorized activation, verify actual BAT0 `charge_control_start_threshold`/`charge_control_end_threshold` read `85`/`90`; UPower's configured values alone do not prove application. A battery already above 90% is not forcibly discharged.

## Checking

Run `nix fmt`, then `nix build --no-update-lock-file --no-link .#nixosConfigurations.thinkpad.config.system.build.toplevel`. That establishes evaluation and closure construction only — the generated-config validators (`hyprland --verify-config`, Noctalia, Ghostty, herdr) no longer run anywhere, so a malformed generated config now surfaces at login instead.

ThinkPad's fresh candidate is deployment-disabled. It still evaluates and builds like every host. Never activate the fresh layout over the running installation without its separate review and authorization. Login, graphical, peripheral, printer, network and boot behaviour all need separate authorization and real hardware.
