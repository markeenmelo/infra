# ThinkPad desktop

A Hyprland + Noctalia desktop for `marcos`. Display/layout/shell policy is authored from observed hardware; the user subsequently authorized reusing the current **application and shell preferences** listed below. The other two hosts remain headless and have no Home Manager evaluation. See [current host status](hosts.md#current-status) for commissioning, deployed/candidate differences and outstanding acceptance. Existing storage, access and recovery protections still apply.

## Ownership and defaults

- `modules/desktop.nix`: owns the selected `desktop` bundle's NixOS/Home Manager bridge, authenticated-session review and ThinkPad's deliberate `home.stateVersion = "26.05"`. That version is not recovered historical state and must not follow future package updates. The fleet evaluator has no desktop-specific branch.
- `modules/desktop/hyprland.nix`: Hyprland through UWSM and `start-hyprland`, PipeWire/portals and structured native HM Lua settings. Only dispatcher expressions use `mkLuaInline`; there is no handwritten whole Lua file.
- `modules/desktop/noctalia.nix`: native **Noctalia Greeter** (still backed by greetd), private greeter/AccountsService state, and one graphical-session-bound shell service owning the bar, launcher, notifications, polkit prompts, lock screen and idle handling. No second compositor autostart, hypridle, notification daemon or locker.
- `modules/desktop/displays.nix`: observed panel facts, shared by native settings and the EDID-gated hotplug/lid output script and its check.
- The desktop bridge imports the existing unstable Home Manager only for this bundle; stable desktop composition is rejected. Unused stable HM was removed, **not stable Nixpkgs**. `useGlobalPkgs` and `useUserPackages` keep the host's package universe and NixOS-managed user profiles. There are no standalone HM outputs, package overlays or new cache trust. Inputs are named `home-manager` and `zen-browser`, with default-branch GitHub URLs and unstable follows links; `flake.lock` alone pins their revisions. Zen is a normal flake input, but its recipe is still instantiated with the host's `pkgs` instead of upstream's separately imported set.
- `shell.nix`, `terminal.nix`, `editor.nix`, `browser.nix`, `agents.nix` and `bitwarden.nix` own approved app preferences; fingerprint, Wi-Fi, printing, Bluetooth, files, controls and KDE Connect have separate concern files with their corresponding services, host policy and state. They deliberately contribute to the shared `desktop` destination; this is not a set of unused per-app toggles. `checks.nix` and `wifi-checks.nix` own cross-layer regressions, while display/printing checks stay beside their implementations.

New choices: dwindle tiling, US keyboard layout, natural touchpad scrolling/tap-to-click, touchpad disabled while typing, three-finger workspace swipe, 4/8-pixel inner/outer gaps, 8-pixel corners, opaque windows and no blur/shadow. Noctalia uses built-in dark Catppuccin and a fixed, non-auto-hiding top bar. Ghostty and Zen replace Foot and Firefox; approved supporting tools are listed below. No wallpaper, external theme templates, plugins, clipboard history, shell telemetry or online shell content is enabled. The shell/display defaults remain fresh, while the requested application palettes reuse OLED Graphite. Neither palette is an **ICC/HDR calibration**.

The native Noctalia locker keeps nonempty-password PAM `login` and now offers fingerprint verification through fprintd alongside it. Idle defaults lock after 300 seconds and turn displays off after 360; locking before suspend remains requested. This is configuration, **not proof of correct authentication, locking or suspend**.

### Authentication and dock-safe password fallback

The observed Synaptics USB reader is **06cb:00f9**. Enable fprintd without enabling fingerprint PAM fleet-wide: only `noctalia-greetd` and `sudo` opt in; console `login`, SSH and other PAM services remain password/key based. The lockscreen drives fprintd over D-Bus separately.

- **Greeter:** select `Hyprland (UWSM)`. A valid typed password takes the password path without waiting for the reader. Empty submission requests fingerprint fallback; an incorrect password also reaches that alternative. The UI's `allow_empty_password = true` permits *submission*, not empty-password authentication. PAM `allowNullPassword` remains false and its final deny rule remains enabled.
- **Sudo:** type the password normally; submit an empty password to request a scan. Fingerprint waits are bounded (10 seconds, two attempts). This is an alternative authenticator, **not two-factor authentication** or passwordless sudo.
- **Locked desktop:** password entry remains available while Noctalia's fingerprint verifier runs. Test this with an external keyboard and inaccessible/disabled reader before accepting docked operation.
- **Keyring:** the dedicated graphical PAM stack stashes a typed password and greetd has an explicit keyring session hook. The ordinary greetd `enableGnomeKeyring` toggle is ineffective at this pin because greetd disables generated PAM rules. Fingerprint-only login **cannot unlock a password-encrypted keyring**; unlock it with its password when needed. Bitwarden vault unlock is separate again.
- No fingerprint was enrolled, verified, deleted or copied. Review existing enrollments privately, then arrange explicit enrollment/verification during authorized acceptance. Protect `/var/lib/fprint` and its backups as identity material. Biometrics do not replace LUKS disk-unlock credentials or console recovery.

### Main bindings

| Binding | Action |
|---|---|
| Super + Enter / B / E | Ghostty (running Herdr) / Zen / Nautilus |
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

## Applications and approved utilities

Current preferences were read from the previous configuration and re-expressed locally; the candidate has **no dependency on that repository or live dotfiles**.

| Application | Configuration |
|---|---|
| Ghostty 1.3.1 / Herdr 0.9.0 | Native HM modules; OLED Graphite, JetBrainsMono Nerd Font, opaque terminal, Herdr as command; Ctrl+A prefix, Zsh default, restored sessions/agent indicators. Disable Herdr release fetching; its native checker accepts the generated config. Review the mutable background server/session state before reuse or replacement |
| Zed 1.19.2 | Native HM settings/theme/LSPs; OLED Graphite and JetBrainsMono Nerd Font for UI/buffer/terminal, telemetry/update disabled. Nix formatting uses the repository's official `nixfmt -`, not Alejandra. Preserve pre-1.19 explicit-submit project search (`search_on_type = false`). Settings are declarative, not writable through Zed's settings UI |
| Zen 1.22b | Current privacy/search/theme policies, default HTTP(S)/HTML handler. Retain pinned Bitwarden, uBlock Origin, YouTube Enhancer, SponsorBlock, Proton VPN and SimpleLogin extensions; no profile/vault/credential copying. Browser/extension updates require reviewed source/XPI pin updates |
| Pi 0.85.1 | Native HM settings and package; default `openai-codex/gpt-6-astra`; [pinned extensions, subagents, plan mode and Nix/Python/JS/C/C++ LSP](pi.md), Codex usage/search and direct fetching. Project trust **ask**, rewind restoration **ask**, no automatic restore on resume/fork/clone. OAuth/API credentials stay mutable and private in the existing home |
| Bitwarden 2026.8.0 (Electron 43.5.1) | Desktop/CLI and local SSH socket routing. Preserve forwarded agents in inbound SSH sessions; disable competing GCR SSH agent, not Secret Service. The app still owns vault unlock, enabling its SSH agent/browser integration and its own autostart |

Only the patched **JetBrainsMono Nerd Font** package is explicitly installed for these apps; the regular JetBrains Mono package is removed. It supplies prompt/developer icons, while native **Noto Color Emoji** fallback remains separate. Font-family/config checks do not establish every glyph's rendering in a live session.

ThinkPad also gets **nh 4.4.2** through `modules/nh.nix`, with the observed `/home/marcos/projects/infra` checkout as its default flake and automatic cleanup disabled. It is not enabled on either server. See [nh operation boundaries](operations.md#thinkpad-nix-helper-nh); it does not replace canonical checks or commissioning.

The current Pi extension set needs Claude Code 2.1.266 and Cursor CLI as provider dependencies; only those two unfree package names are allowed on the desktop. Standalone Claude/Cursor settings/hooks were not imported. Pi's store-backed settings cannot persist `/settings`, model saving or `pi install`; modify declarative settings instead. Updating Herdr/Pi requires reviewing the vendored hook and extension compatibility, not letting an updater overwrite store-backed files. Herdr 0.8.2 and 0.9.0 ship the same Pi hook bytes as the committed extension. The installed model catalog and deployed settings confirm `openai-codex/gpt-6-astra`; provider authentication and the updated extension runtime still require application-level acceptance.

Zen's SponsorBlock/YouTube Enhancer settings exports live under `~/.config/sponsorblock/` and `~/.config/youtube-enhancer/` for **manual UI import**; the browser does not automatically consume them. The reused Bitwarden extension's self-hosted endpoint is unchanged, not a newly verified server. Extension/vault settings may require UI acceptance; never weaken TLS to make them connect.

Approved additions: Nautilus, File Roller/GVfs/UDisks, Papers, Loupe, Simple Scan, btop, pavucontrol, NM connection editor, Bluetooth, KDE Connect, and Zsh/Starship/fzf/zoxide/ripgrep/fd/bat/eza. Preserve the current Git identity and safe zoxide/Starship hook ordering. **No media player**, second shell/polkit/notification agent or blanket Thunderbolt authorization was added. The NM editor package also contains nm-applet, but its packaged autostart is masked: Noctalia owns the agent. KDE Connect's packaged autostart is similarly masked in favor of its one HM session service. Native XDG/desktop-file builders create only these two `Hidden=true` overrides; other autostarts stay mutable and collisions still block activation.

KDE Connect opens TCP/UDP **1714–1764**; Avahi discovery opens UDP **5353**, on ThinkPad only. Pair only intended devices and review this exposure on public/campus networks. Bluetooth is powered on at boot; no devices are paired automatically. CUPS listens on localhost only with no shared queues or CUPS firewall opening. The existing Epson ET-3850 endpoint is `ipps://192.168.4.20:631/ipp/print`; it was reviewed in the previous configuration, **not contacted or certificate-verified**. Scanner discovery uses sane-airscan, not an invented scanner URI. Verify printer address/TLS, printing and scanning during authorized acceptance.

### Home printer provisioning

The native `ensure-printers.service` is **manual-only**: no boot target, timer or restart-on-rebuild. Normal boots reuse the queue, default-printer selection and PPD under persisted `/var/lib/cups`, without querying the home printer. If that state is absent, printing stays unprovisioned rather than blocking boot or silently retrying the network.

Only during separately authorized provisioning, with the printer online on the verified home network, create or refresh the declared queue/default:

```sh
sudo systemctl restart ensure-printers.service
```

This explicitly runs native `lpadmin -m everywhere`, which contacts the printer even if the queue already exists. A failure remains a failed operation and stops before setting the default; there is no fallback or retry. Queue-definition changes also require this deliberate reprovisioning. No CUPS state is deleted or copied by this review fix.

## Wi-Fi credentials

Native `networking.networkmanager.ensureProfiles` generates profiles in `/run/NetworkManager/system-connections` with root-only permissions. A root service prepares `/run/fleet-wifi-environment/credentials.env` (directory `0700`, file `0600`) from root-only SOPS files. It escapes both systemd quoting and GLib keyfile syntax; credentials never enter Nix values, the store, command arguments or logs. Do not persist `/run` outputs.

- **MN-Home:** reuse encrypted `wifi-psk` and existing profile UUID; autoconnect enabled. `psk-flags = 0` makes it system-owned, not dependent on a desktop secret agent. The old file-secret agent and its Noctalia contention patch are not copied.
- **SenecaNET:** the separate ciphertext is **filled and selected**, following the operator-run private audit on 2026-09-10. MAC/decryption, marker rejection and username-only/single-line checks passed; no credential value was exposed. The policy remains PEAP with MSCHAPv2, `/etc/ssl/certs/ca-certificates.crt`, certificate domain suffix **senecapolytechnic.ca**, empty anonymous identity, and username **before `@`**. [Current status](hosts.md#current-status) records the completed runtime profile/secret delivery; actual campus authentication and server-certificate rejection remain untested. Initial connection remains deliberate (`autoconnect = false`). A null selector still blocks unprovisioned configurations.

For future campus provisioning/replacement, follow [Fill the SenecaNET placeholders locally](../secrets/README.md#fill-the-senecanet-placeholders-locally). The separate **`secrets/hosts/thinkpad-senecanet.yaml`** uses **`seneca-identity`** and **`seneca-password`**, with the existing public recipients and no password/PSK file changes. Its initial markers were replaced privately and the file reviewed before `fleet.wifi.senecaSopsFile` was selected. Unfilled configurations must keep the selector null; the runtime adapter still rejects markers rather than delivering dummy credentials. Do not use trailing-newline literal blocks, credentials in shell arguments/chat or plaintext repository files. Run `devenv tasks run repo:secret-check` before staging and `devenv tasks run repo:check` afterward. The template manifest test can pass on markers: it validates key selection, not credential usability or decryption. No review flag is bypassed.

Before activation, review duplicate/stale NetworkManager profiles (including the old MN-Home UUID/agent-owned flags) and back up/reconcile them deliberately. Do not blanket-delete profiles. On campus, confirm the current CA/name policy with Seneca IT and test certificate rejection before acceptance; **never select “no CA certificate,” suppress server-name checks or accept an unexplained certificate**. Indexed official instructions were available; direct page access returned 403. PEAP/MSCHAPv2 depends on this TLS validation to protect credentials. No Wi-Fi connection was changed. The separately authorized local SOPS audit established the limited facts above, not network acceptance.

## Mobile and docked displays

Observed on **2026-09-10**: internal `eDP-1`, Chimei Innolux `0x143F`, **1920×1200 @ 60.003 Hz**, scale 1; external `DP-3`, Samsung Odyssey G93SC, preferred/native **5120×1440 @ 59.977 Hz**. The external EDID advertises BT.2020, PQ/ST2084, static HDR metadata and 10-bit support with a desired 400 cd/m² maximum. The internal panel is 8-bit SDR. GPU selection remains automatic; no new NVIDIA/eGPU path is inferred from the connector.

- With no external output, keep eDP-1 at its exact observed mode, scale 1, SDR/sRGB, 8-bit and VRR off.
- Only outputs matching **connected DRM connectors** count as externals; virtual `FALLBACK` and arbitrary headless outputs cannot replace the panel. Eligible externals are sorted into one top row and use each EDID's preferred mode at scale 1. The internal panel is centered beneath the full row. A non-mutating open-lid dry-run placed the external at `(0,0)` and internal at `(1600,1440)`; a later closed-lid dry-run kept the external rule and emitted `eDP-1,disable`.
- The runtime policy enables 10-bit `hdredid` only when `edid-decode` finds BT.2020 RGB, PQ/ST2084 and an HDR static-metadata block. Other outputs retain 8-bit sRGB. No luminance or ICC value is invented, and VRR remains off.
- Closing the lid disables eDP-1 only after a fresh active-monitor snapshot confirms a connected physical external is enabled, DPMS-on and has positive dimensions. An inactive/rejected external or failed query leaves the panel untouched and fails the sync. Opening the lid restores the centered layout; disconnecting the last external while closed restores eDP-1 to avoid a blank session. A locked watcher handles only legacy monitor add/remove events (not their duplicate v2 notifications) plus `configreloaded`, and locked lid binds trigger the same synchronization. Initial sync waits for confirmed socket subscription, then a brief compositor-publication delay; a failed subscription permits no output mutation.
- Monitor JSON/row decoding completes before any rule is applied. Updates use Lua `hl.monitor` via `hyprctl eval`, never legacy `keyword monitor`; only the exact `ok` reply acknowledges a queued rule, not a successful modeset. Enabling explicitly sets `disabled = false` because Lua updates inherit existing rules. Command, protocol rejection, EDID decoding, hardware-read and socket failures stop processing instead of silently selecting SDR, continuing to disable eDP-1 or retrying. Already applied rules are not rolled back; diagnose failures before starting a new watcher/session.
- No `/dev/dri/cardN` pin, PRIME bus IDs, global NVIDIA environment, NVIDIA driver selection, wildcard Bolt authorization or device enrollment is added. Rendering GPU and connector-owning GPU can differ.

Earlier live **dry-runs** planned the intended layout without issuing a modeset. Cold-docked inspection later found static side-by-side 8-bit rules and an active closed-lid panel despite a running watcher. The initial startup-race diagnosis was incomplete: review found legacy IPC incompatible with the selected Lua parser. The branch now uses Lua IPC with rejection checks and retains the subscriber-first settling guard; isolated tests and native config parsing do not establish runtime acceptance. See [dated review evidence](research.md#repository-review-corrections--2026-09-11). Follow-up acceptance must test cold docked/undocked login, hotplug, config reload, lid close/open, last-external removal while closed, HDR content/SDR mapping and `hyprctl configerrors`. Preferred mode means the EDID-designated native mode, not the non-native 3840×2160 timing or lower-resolution 144 Hz modes also advertised by this ultrawide. Ten-bit alone is not HDR; OLED VRR flicker is not eliminated by a compositor setting. Do not assume unplugging an active eGPU is safe or seamless.

## Kernels and Intel driver

Keep **`i915`** for the observed Alder Lake-P GPU; the hardware's Iris Xe branding does not mean the newer Linux `xe` driver is preferable. No experimental force-probe, GPU blacklist, NVIDIA driver or kernel tuning is added. `modules/kernel.nix` selects stock `linuxPackages_latest` from each host's own locked track: **7.2.4 on all three hosts**. These are the latest available in those pins, not a claim every track packages kernel.org's newest patch.

OpenZFS **2.4.4** declares 7.2 support; Bastion's actual 7.2.4 kernel/ZFS module and initrd derivations evaluate with compatibility guards intact. This is **not a kernel/module build, pool import or boot test**. Future updates must retain a supported pair, major 7 and host-track isolation; they must fail rather than allow a broken ZFS module or silently cross to 8.x. Follow kernel EOL, retain recovery generations and check ESP capacity before boot acceptance.

## Fresh configuration and durable state

Home Manager manages generated Hyprland Lua, Ghostty/Herdr/Zed settings and themes, Pi settings/extensions, shell configuration/MIME defaults and the shell's **new** `~/.config/fleet-desktop/noctalia/config.toml`. The Noctalia service uses its supported `NOCTALIA_CONFIG_HOME`, `NOCTALIA_STATE_HOME` and `NOCTALIA_DATA_HOME` overrides. Its state and data are under:

- `~/.local/state/fleet-desktop/noctalia/`
- `~/.local/share/fleet-desktop/noctalia/`

The service does not read/delete old `~/.config/noctalia`, `~/.local/state/noctalia` or `~/.local/share/noctalia` settings/plugins. It does not change other applications' XDG paths. Normal `noctalia msg …` IPC still targets the current Wayland session. To start/restart the intended shell later, use its user service rather than launching a second default-profile instance.

The new profile can still acquire GUI overrides in `settings.toml`; those override the declarative base. For reproducibility, put accepted choices in the module and deliberately reconcile corresponding GUI overrides after backup. Do not automatically remove state to enforce a theme. Only the explicitly requested declarative app preferences/public assets were copied. Browser/vault/keyring profiles and credentials were neither read into Git nor migrated or erased; applications may naturally use their existing private profiles.

`/home` is already a separate early-mounted durable filesystem. No duplicate impermanence binds for configuration, shell state, user PipeWire state or `~/.local/share/keyrings` are necessary. These paths are persistent user data, not backups. New scoped system persistence covers `/var/lib/fprint` (`0700`), `/var/lib/AccountsService` (`0700`), `/var/lib/noctalia-greeter` (greeter-owned `0750`), `/var/lib/bluetooth` (`0700`) and `/var/lib/cups` (queues/PPDs). Caches and print-job spool remain ephemeral; finish pending jobs before reboot/transition. Preserve existing state with correct ownership during separately authorized migration, not broad home/root copies. Native greeter tmpfiles replaces `greeter.toml` with the generated system configuration; back up existing greeter settings/state first.

## Activation and acceptance checklist

1. Preserve console/recovery access and the previous generation; resolve [existing-host transition gates](hosts.md) and [SOPS identity/password delivery](../secrets/README.md). A working old login is not proof the candidate will decrypt the password.
2. Review the current Home Manager generation, unmanaged dotfiles, legacy `hyprland.conf`/Lua/includes, Ghostty/Herdr/Zed/Pi/shell/MIME configs, Bitwarden/old desktop services/autostarts and systemd user overrides. Home Manager's `legacy` file activator and collision detection are retained: no `force`, automatic backup-renaming or user-file deletion. Back up and resolve any collisions deliberately before authorized activation. Stop competing shells/lockers as part of a reviewed session transition, not by blindly disabling arbitrary services.
3. Verify the new Noctalia profile paths are unused or contain only intended new state. Review the fresh keyboard/layout/bindings. GUI settings must not accidentally disable locking. Review fingerprint enrollments and password/keyring behavior, provision missing campus ciphertext, and reconcile old NM profiles/agents. Noctalia may still prompt for unknown networks; declarative home/campus profiles use system-owned runtime secrets.
4. `devenv tasks run repo:fmt`, then `devenv tasks run repo:check` ([locked native bootstrap](development.md#start)). Both-track infrastructure fixtures remain; desktop policy/activation tests cover unstable and actual ThinkPad. Native binaries check generated Hyprland/Noctalia/Ghostty/Herdr configs, JSON/TOML parsers inspect the other settings, Zen's wrapper/desktop entry is built, font families and nh help/version are checked, and offline Wi-Fi/manifest tests check escaping, marker rejection and encrypted-key selection. Isolated output-policy tests cover virtual outputs, reloads and fail-fast handling; native printer unit/script checks cover manual-only provisioning and offline failure propagation. These do not start a graphical session, decrypt credentials or build/boot a full machine.
5. The original desktop review and two-boot commissioning acceptance are recorded in [hosts.md](hosts.md#first-boot-acceptance-2026-09-10-utc). The maintenance generation has since booted, but its limited runtime checks do not certify the dependency, printer or HDR/output-policy change; cold docked startup exposed the unapplied monitor rules described above. Keep `fleet.desktop.reviewed` tied to the genuine review rather than toggling it to disguise an incomplete update. `devenv shell ready thinkpad` and `devenv shell build thinkpad` are additional local checks, not activation permission.
6. During a separately authorized follow-up activation, retain the previous Limine generation and test the Lua IPC correction and startup guard with cold docked/undocked login, hotplug, config reload, lid close/open, last-external removal while closed and HDR/SDR rendering. Also complete visual fixed-bar acceptance, Pi/provider and Herdr agent behavior, Zed explicit-submit search, Bitwarden startup/browser integration, KDE Connect pairing/transfer, printing/scanning, password login, lock-before-suspend, audio/portals and console recovery. Check `herdr status` before replacing any surviving pre-update server or risking its panes. Review user/system journals without publishing sensitive desktop content.

See [ADR 0008](adr/0008-native-desktop-and-kernels.md), the original [ADR 0007](adr/0007-thinkpad-desktop.md), [update/display research](research.md#full-dependency-and-thinkpad-display-policy-update--2026-09-10) and [validation scope](validation.md). All fleet readiness flags and the no-provisioning boundary remain intact.
