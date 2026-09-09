# ThinkPad desktop

A **new** Hyprland + Noctalia desktop for `marcos`, not a copy of the old desktop. Only observed hardware facts inform its display/GPU configuration. The other three hosts remain headless. ThinkPad is still uncommissioned and local-only; **nothing has been activated**. Existing storage, access and recovery gates still apply.

## Ownership and defaults

- `modules/desktop/hyprland.nix`: deferred NixOS/Home Manager capability; password-authenticated greetd/tuigreet, Hyprland through UWSM and `start-hyprland`, PipeWire, portals, GNOME Keyring/PAM, and new bindings/layout.
- `modules/desktop/noctalia.nix`: contributes to that same Home Manager value; one graphical-session-bound shell service owns the bar, launcher, notifications, polkit prompts, lock screen and idle handling. No second compositor autostart, hypridle, notification daemon or locker.
- `modules/desktop/thinkpad.nix`: selects `marcos`, deliberate new `home.stateVersion = "26.05"`, and the observed internal-panel mode. This is not a recovered historical Home Manager stateVersion and must not follow future package updates.
- `modules/fleet.nix` selects the Home Manager integration matching each host's Nixpkgs track. `useGlobalPkgs` and `useUserPackages` keep packages in that host's package set and NixOS-managed user profiles. There are no separate standalone Home Manager outputs, desktop flake inputs, overlays or new cache trust.

New choices: dwindle tiling, US keyboard layout, natural touchpad scrolling/tap-to-click, three-finger workspace swipe, 4/8-pixel inner/outer gaps, 8-pixel corners, opaque windows and no blur/shadow. Noctalia uses built-in dark Catppuccin and an auto-hiding top bar. Foot and Firefox are the only explicitly added interactive applications. No wallpaper, external theme templates, plugins, clipboard history, shell telemetry or online shell content is enabled. These are fresh defaults, not imported preferences; shell colors are **not** an ICC/HDR calibration.

The native Noctalia locker requires a nonempty password through PAM `login`; fingerprint unlocking is off. Idle defaults lock after 300 seconds and turn displays off after 360. Noctalia requests locking before suspend. This is configuration, **not proof of correct locking or suspend on this machine**. GNOME Keyring's login PAM integration can unlock a password-matching keyring; it neither provisions Wi-Fi credentials nor verifies existing keyring compatibility.

### Main bindings

| Binding | Action |
|---|---|
| Super + Enter / B | Foot / Firefox |
| Super + Space / A | Launcher / control center |
| Super + Shift + L | Lock |
| Super + Shift + Escape | Session menu |
| Alt + Tab / Print | Window switcher / region screenshot |
| Super + Q / V / F | Close / toggle floating / toggle fullscreen |
| Super + arrows | Focus direction |
| Super + Shift + arrows | Move window |
| Super + 1…9, 0 | Workspaces 1…10; add Shift to move a window |
| Super + left/right mouse drag | Move/resize window |
| Volume, microphone-mute, brightness keys | Noctalia native controls |

## Mobile and docked displays

Observed on **2026-09-09**: ThinkPad T14 Gen 3, Intel i915 `8086:46a6` at PCI `0000:00:02.0`; `eDP-1`, Chimei Innolux `0x143F`, **1920×1200 @ 60.003 Hz**, scale 1. It was the only connected output. A Razer Core X was listed by Bolt but disconnected; no NVIDIA PCI device or Samsung EDID was available. Historical RTX 3070/G93SC references are not newly verified hardware facts.

- Mobile: keep the internal panel enabled, scale 1, SDR/sRGB, 8-bit, VRR off.
- Any other output: preferred mode, automatic placement, scale 1 and the same conservative SDR policy. No guessed Samsung connector, refresh, luminance, HDR metadata or ICC path. The internal panel is not automatically disabled when docking.
- GPU selection remains automatic. No unstable `/dev/dri/cardN` pin, PRIME bus IDs, global NVIDIA environment or NVIDIA driver selection. Ordinary Intel support remains the working baseline, not a claim that an eGPU already works.
- Existing Bolt authorization is preserved; no wildcard authorization or new device enrollment. Rendering GPU and connector-owning GPU can differ. A future multi-GPU policy must include the GPUs needed for all connected displays, not force Intel in a way that hides eGPU connectors.

Before an NVIDIA/Samsung profile, obtain the live PCI ID/model, driver/kernel compatibility, external EDID/modes, actual connector and physical cable/dock route. Verify bandwidth/DSC and measured display behavior before choosing maximum refresh + 10-bit/HDR or fullscreen-only VRR. Ten-bit alone is not HDR; OLED VRR flicker is not eliminated by a compositor setting. Test cold docked login and undocked login first. Do not assume unplugging an active eGPU is safe or seamless; close affected applications/log out for initial disconnect tests. This follow-up needs the actual hardware, not speculative driver flags.

## Fresh configuration and durable state

Home Manager manages `~/.config/hypr/hyprland.lua`, `~/.config/foot/foot.ini` and the shell's **new** `~/.config/fleet-desktop/noctalia/config.toml`. The Noctalia service uses its supported `NOCTALIA_CONFIG_HOME`, `NOCTALIA_STATE_HOME` and `NOCTALIA_DATA_HOME` overrides. Its state and data are under:

- `~/.local/state/fleet-desktop/noctalia/`
- `~/.local/share/fleet-desktop/noctalia/`

The service does not read/delete old `~/.config/noctalia`, `~/.local/state/noctalia` or `~/.local/share/noctalia` settings/plugins. It does not change other applications' XDG paths. Normal `noctalia msg …` IPC still targets the current Wayland session. To start/restart the intended shell later, use its user service rather than launching a second default-profile instance.

The new profile can still acquire GUI overrides in `settings.toml`; those override the declarative base. For reproducibility, put accepted choices in the module and deliberately reconcile corresponding GUI overrides after backup. Do not automatically remove state to enforce a theme. Nothing copies existing application preferences, browser profiles or user data; existing home contents still exist and applications may naturally use their own prior profiles.

`/home` is already a separate early-mounted durable filesystem. No duplicate impermanence binds for configuration, shell state, user PipeWire state or `~/.local/share/keyrings` are necessary. These paths are persistent user data, not backups. Shared system state remains owned by its existing capabilities.

## Pre-activation and acceptance checklist

1. Preserve console/recovery access and the previous generation; resolve [existing-host transition gates](hosts.md) and [SOPS identity/password delivery](../secrets/README.md). A working old login is not proof the candidate will decrypt the password.
2. Review the current Home Manager generation, unmanaged dotfiles, legacy `hyprland.conf`/Lua/includes, Foot config, old desktop services/autostarts and systemd user overrides. Home Manager collision detection is retained: no `force`, automatic backup-renaming or user-file deletion. Back up and resolve any collisions deliberately before authorized activation. Stop competing shells/lockers as part of a reviewed session transition, not by blindly disabling arbitrary services.
3. Verify the new Noctalia profile paths are unused or contain only intended new state. Review the fresh keyboard/layout/bindings. GUI settings must not accidentally disable locking. Existing keyring and NetworkManager secret-agent compatibility still require acceptance; shell integration is not Wi-Fi-secret migration.
4. `nix develop --no-update-lock-file -c just fmt`, then `nix develop --no-update-lock-file -c just check`. Both-track fixtures evaluate the module/session/security policy, and native binary checks parse generated Hyprland Lua and validate Noctalia TOML (warnings also fail). These do not start a graphical session or build/boot a full machine.
5. `fleet.desktop.reviewed` stays **false** until a real review of login, PAM locking/sleep, portals, audio and mobile display behavior is recorded. It is not NVIDIA/HDR certification and must not be set just to obtain an activation. Arrange any initial target test as a separately authorized commissioning step, retaining all bootstrap and recovery protections. After genuine commissioning, `just ready thinkpad` and `just build thinkpad` are additional local checks, not deployment permission.
6. During separately authorized target acceptance, test password login/logout, service lifecycle, lock/unlock and failed authentication, idle display-off/wake, lid/suspend/resume with the lock held, battery behavior, microphone/speaker/headphone switching, notifications/polkit, keyring/network prompting, browser file chooser and screencast/screen sharing. Review `hyprctl configerrors` and user journal diagnostics without publishing sensitive desktop content. Test external display appearance/disappearance separately; never treat the internal-panel test as eGPU/HDR acceptance.

See [ADR 0007](adr/0007-thinkpad-desktop.md), [pinned API research](research.md#thinkpad-hyprland--noctalia--home-manager--2026-09-09) and [validation scope](validation.md). All fleet readiness flags and the no-provisioning boundary remain intact.
