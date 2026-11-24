---
name: desktop
description: "The Linux desktop role and the workstations' look: the role's modules (Home Manager, NetworkManager, PipeWire, Umbriel, Noctalia, Wi-Fi, printing, the desk monitor, Bitwarden as SSH agent), idle, lid and power behaviour, and the rules every theme follows: Omarchy-style design, Tokyo Night through Stylix, fonts, spacing, borders, color roles, bars, notifications, and how an app is themed or hand-tuned. Use before touching modules/{desktop,umbriel,noctalia,wifi,printing,odyssey,bitwarden,stylix}.nix, a window manager, bar, terminal, editor or any app's appearance, or adding a desktop app."
---

# Desktop

The workstation runs Umbriel for windows and Noctalia for the bar. The design follows **Omarchy**:
square, opaque and gapped, Tokyo Night throughout, on this stack instead of Hyprland.

## Theming

[stylix.nix](../../../modules/stylix.nix) sets the one scheme, Tokyo Night (`tokyo-night-terminal-dark`,
whose base16 slots keep red, yellow and blue in the roles below, unlike `tokyo-night-dark`, with
the text, muted text and success slots overridden to Tokyo Night's own so every role holds), dark
polarity, and the fonts; every app that Stylix can theme takes its colors and fonts from it. An
app is then hand-tuned in its own module to the rules below, reading `config.lib.stylix.colors`
(base16 names) and `config.stylix.fonts`, never a hex or font literal, so a scheme or font change
reaches it. An app Stylix cannot theme gets the same treatment by hand.

An app that ships its own Tokyo Night uses it for syntax instead of Stylix's base16 colors, while
its fonts still come from Stylix: its target is disabled and the native theme is selected, with its
background and surfaces overridden from `base00`–`base02` so it sits on the same black as the rest.
Only Neovim does (`tokyonight-nvim`, style `night`, in [neovim.nix](../../../modules/neovim.nix));
Zed and bat, which ship no Tokyo Night, take Stylix's.

Terminals and desktop chrome stay on Stylix. [tmux.nix](../../../modules/tmux.nix) draws its status
line and pane borders from the same palette (prefix `C-a`, vi keys, sessions restored by
resurrect and continuum), and Ghostty attaches to its session `main`. Zed's settings file is
immutable; its extensions, language servers and keymaps are declared in zed.nix.

## Rules

- **Surfaces:** every surface is opaque and solid, focused or not, with no blur and no drop shadow:
  app windows, the bar, the launcher, notifications and popups alike; the border color alone marks
  focus. The lock screen's blurred wallpaper is the only blur.
- **Quick terminal:** none: Umbriel has no global-shortcuts portal for Ghostty's own, and
  its scratchpad is unused, the stock binds parked in [umbriel.nix](../../../modules/umbriel.nix).
- **Launcher:** `Mod + Space` or the bar's launcher button, on the Linux laptops only; Umbriel's stock tap on `Mod` is parked
  in [umbriel.nix](../../../modules/umbriel.nix) with the scratchpad binds.
- **Motion:** quick ease-out with no bounce: windows pop in from 87% over 300 ms and pop out over
  120 ms, other transitions take 300 ms, and switching workspaces is instant
  ([umbriel.nix](../../../modules/umbriel.nix)).
- **Spacing:** 10 px between windows and to the screen edge (the bar's edge counts as the
  screen's). Terminal padding 10 px across, 8 px down.
- **Borders:** 2 px around windows; `base0D` on the focused one, `base02` on the others. Umbriel
  takes one color per border, so focus is a solid accent, not a gradient.
- **Rounding:** none: windows, bar items, buttons, notifications and popups are square (Noctalia's
  `corner_radius_scale = 0`). Only the lock screen's login box keeps Noctalia's own radii.
- **Bar:** top, 32 px tall, `base00`, monospace semibold at 13, flush with the
  screen edges and square. Status items are text or one
  monochrome Nerd Font glyph each, no colored icons, no graphs; a third-party item that colors
  its text for no state is patched to the text color.
- **Grouping:** none: items sit flat on the bar, 8 px apart. An item shows only while it carries
  news (an event within two hours); a steady "all fine" state stays out of the bar and in its
  tooltip; only the CPU load always shows, as Omarchy's monitor does.
- **Bar items:** on the left the launcher and the workspaces as plain numbers; in the center the
  clock (`%A %H:%M`), agenda and weather; on the right the tray, tailnet, bluetooth, volume,
  network, CPU (as text), battery and notifications. Noctalia holds them
  ([noctalia.nix](../../../modules/noctalia.nix)), the agenda through this repository's own plugin
  ([agenda](../../../modules/noctalia-plugins/agenda/widget.luau)). An item that holds
  more opens a `base01` popup next to
  it on click: the clock lists today's events, volume has a slider, and tailnet lists the exit
  nodes to switch to.
- **Notifications:** top right, `base01` background, a 2 px `base0D` border, or
  `base08` for critical ones.
- **Icons:** Nerd Font glyphs in the text color; color only where it carries state.

## Color roles

One accent: `base0D` (blue) marks focus, selection and the active item, and nothing decorative.

| Role | base16 |
|---|---|
| Background | `base00` |
| Raised surface (popups, notifications) | `base01` |
| Selection, inactive borders | `base02` |
| Muted text (comments, hints) | `base03` |
| Text | `base05` |
| Accent | `base0D` |
| Error, critical | `base08` |
| Warning | `base0A` |
| Success | `base0B` |

## Type

All set in Stylix, so every target agrees, except the bar's size and weight, which the bar's
module sets ([noctalia.nix](../../../modules/noctalia.nix)):

| Use | Font | Size |
|---|---|---|
| Terminals, editors, code | JetBrainsMono Nerd Font Mono | 12 |
| Application UI, desktop, popups | NotoSans Nerd Font Propo | 11 |
| Bar | JetBrainsMono Nerd Font Mono, semibold | 13 |
| Serif slots | Noto Serif | as the app asks |
| Emoji | Noto Color Emoji | as the text |

No other families. Glyph icons come from the Nerd Font, never from a second icon font.

## Cursor, icons and wallpaper

- **Cursor:** Bibata Modern Classic, 24 px, through Stylix on the Linux laptops.
- **Icons:** Papirus-Dark through Stylix for GTK and Qt apps on the Linux laptops; bar and
  status glyphs stay Nerd Font (see Rules).
- **Wallpaper:** [wallpaper.jpg](../../../modules/wallpaper.jpg), set as Stylix's `image`, which
  applies it. It is the only image in the look; nothing else is
  derived from it, since the colors come from Tokyo Night, not from the picture.
- **Lock screen:** the wallpaper, blurred, with the clock in NotoSans Nerd Font Propo and the password field on a
  `base01` surface with Noctalia's own radii.

## Toolkits and sound

- **GTK and Qt:** themed by Stylix (adw-gtk3 dark for GTK, Qt following it), never a second
  theme engine; dark mode is on everywhere it can be asked for.
- **Sound:** no event or notification sounds; alerts are visual.
- **System accent:** where the OS has one, it is blue, matching
  `base0D`.

## The Linux desktop role

The role is one file per concern, each setting its NixOS and Home Manager halves: the base in
[desktop.nix](../../../modules/desktop.nix) (Home Manager as a NixOS module, NetworkManager,
Bluetooth, PipeWire, UPower, the apps), [umbriel.nix](../../../modules/umbriel.nix)
(the compositor session from nixpkgs' module, and `programs.umbriel.settings`, a config layered
over Umbriel's packaged `config.toml`: tables merge by key and the last file wins, so only changes
to stock are written; hosts and odyssey.nix add their outputs; `Mod + /` lists the keybinds),
[noctalia.nix](../../../modules/noctalia.nix) (bar, launcher, notifications, lock, idle, the polkit agent, the greeter,
whose output layout is derived from Umbriel's positions; apps it launches run as their own systemd
units, so a shell restart does not take them down; the `desktop-config-HOST` check fails on any
key either program's validator rejects or warns about),
[wifi.nix](../../../modules/wifi.nix), [printing.nix](../../../modules/printing.nix) and
[odyssey.nix](../../../modules/odyssey.nix) (the desk monitor's mode and DDC brightness). The tailnet client accepts bastion's subnet routes
so the LANs stay reachable away from home; at home MN-Home is the Home LAN, which bastion does not
advertise, so the laptop's own LAN stays on-link and only the printer, on the IoT LAN, goes
through bastion. Bitwarden's desktop app is the SSH agent
(`~/.bitwarden-ssh-agent.sock`), started at login ([bitwarden.nix](../../../modules/bitwarden.nix)).

Idle locks, turns the screen off and suspends on the timers in
[noctalia.nix](../../../modules/noctalia.nix), unless an app holds an idle inhibitor, as a browser
does while a video plays; on battery two earlier timers there turn the screen off and suspend
sooner. On battery `power-profile-ac` switches to
power-saver and caps the panel brightness, and restores the previous profile and brightness on AC;
the battery charges to 90% and resumes at
85%. The btrfs scrub
([desktop.nix](../../../modules/desktop.nix)) starts on AC only. Shutting the lid removes the built-in panel from the desktop, docked or not, and windows move
to another display until it opens; undocked on AC that leaves no display until the lid opens or the
idle timer suspends, and the idle lock still engages with no output, so opening the lid shows the
lock screen. Shutting it suspends on
battery only: on AC the idle timer does, since a monitor that sleeps drops off DRM and logind would
read that as an undock.
