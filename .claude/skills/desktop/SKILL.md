---
name: desktop
description: "The workstations' look and the rules every theme follows: flat and quiet design, One Dark through Stylix, fonts, spacing, borders, color roles, bars, notifications, and how an app is themed or hand-tuned, on the mac (AeroSpace, SketchyBar, Ghostty) and the Linux laptops (Hyprland, Noctalia). Use before touching modules/stylix.nix, a window manager, bar, terminal, editor or any app's appearance, or adding a desktop app."
---

# Desktop

The workstations look alike: what holds on the mac holds on the thinkpad and asahi, with each
platform's tool in its place (AeroSpace or Hyprland for windows, SketchyBar or Noctalia for the
bar). The design is **flat and quiet**: the desktop recedes and content comes first.

## Theming

[stylix.nix](../../../modules/stylix.nix) sets the one scheme, One Dark, dark polarity, and the
fonts; every app that Stylix can theme takes its colors and fonts from it. An app is then
hand-tuned in its own module to the rules below, reading `config.lib.stylix.colors` (base16 names)
and `config.stylix.fonts`, never a hex or font literal, so a scheme or font change reaches it. An
app Stylix cannot theme gets the same treatment by hand.

## Rules

- **Surfaces:** app windows, terminal included, are solid. The desktop's own chrome (bar,
  launcher, notifications, popups, the quick terminal) may be lightly translucent: its color at
  90% opacity over a soft blur (Hyprland `blur` size 6, 2 passes; SketchyBar `blur_radius` 20), so
  text stays fully readable. No drop shadows anywhere.
- **Motion:** none, or a fade or slide of at most 150 ms; nothing bounces or zooms.
- **Spacing:** multiples of 2 px. Windows: 8 px between them, 6 px to the screen edge (the bar's
  edge counts as the screen's). Terminal padding 10 px across, 8 px down.
- **Borders:** 2 px around windows; `base0D` on the focused one, `base02` on the others. On the
  mac, JankyBorders draws them beside AeroSpace ([aerospace.nix](../../../modules/aerospace.nix)).
- **Rounding:** 6 px on windows where the window manager controls it, 4 px on small elements
  (bar items, buttons, notifications). The mac's own window corners stay as macOS draws them.
- **Bar:** top, 32 px tall, solid `base00`, monospace bold at 13. Workspaces are plain numbers;
  the active one sits on a `base0D` pill with `base00` text. Status items are text or one
  monochrome Nerd Font glyph each, no colored icons, no graphs.
- **Notifications:** top right, `base01` background, 4 px rounding, a 2 px `base0D` border, or
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

All set in Stylix, so every target agrees:

| Use | Font | Size |
|---|---|---|
| Terminals, editors, code | JetBrainsMono Nerd Font | 12 |
| Application UI, desktop, popups | Inter | 11 |
| Bar | JetBrainsMono Nerd Font, bold | 13 |
| Serif slots | Inter (no serif face) | as the app asks |
| Emoji | Noto Color Emoji | as the text |

No other families. Glyph icons come from the Nerd Font, never from a second icon font.

## Cursor, icons and wallpaper

- **Cursor:** Bibata Modern Classic, 24 px, through Stylix on the Linux laptops; the mac keeps
  the macOS cursor.
- **Icons:** Papirus-Dark through Stylix for GTK and Qt apps on the Linux laptops; bar and
  status glyphs stay Nerd Font (see Rules).
- **Wallpaper:** [wallpaper.jpg](../../../modules/wallpaper.jpg), set as Stylix's `image`, so
  every machine shows the same one: Stylix applies it on Linux, and on the mac a Home Manager
  activation step sets it with `desktoppr`. It is the only image in the look; nothing else is
  derived from it, since the colors come from One Dark, not from the picture.
- **Lock screen:** the wallpaper, blurred, with the clock in Inter and the password field on a
  `base01` 4 px rounded surface.

## Toolkits and sound

- **GTK and Qt:** themed by Stylix (adw-gtk3 dark for GTK, Qt following it), never a second
  theme engine; dark mode is on everywhere it can be asked for.
- **Sound:** no event or notification sounds; alerts are visual. On the mac that means no alert
  beep, interface sounds or startup chime ([macos.nix](../../../modules/macos.nix)).
- **System accent:** where the OS has one, it is blue (macOS `AppleAccentColor` 4), matching
  `base0D`.
