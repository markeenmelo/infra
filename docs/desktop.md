# ThinkPad desktop

A Hyprland + Noctalia desktop for `marcos`. Display/layout/shell policy remains newly authored from observed hardware; the user subsequently authorized reusing the current **application and shell preferences** listed below. The other three hosts remain headless and have no Home Manager evaluation. ThinkPad is still uncommissioned and local-only; **nothing has been activated or enrolled**. Existing storage, access and recovery gates still apply.

## Ownership and defaults

- `modules/desktop/hyprland.nix`: deferred NixOS/Home Manager capability; native **Noctalia Greeter** (still backed by greetd), Hyprland through UWSM and `start-hyprland`, PipeWire/portals, and structured native HM Lua settings. Only dispatcher expressions use `mkLuaInline`; there is no handwritten whole Lua file.
- `modules/desktop/noctalia.nix`: contributes to that same Home Manager value; one graphical-session-bound shell service owns the bar, launcher, notifications, polkit prompts, lock screen and idle handling. No second compositor autostart, hypridle, notification daemon or locker.
- `modules/desktop/thinkpad.nix`: selects `marcos`, deliberate new `home.stateVersion = "26.05"`, and the observed internal-panel mode. This is not a recovered historical Home Manager stateVersion and must not follow future package updates.
- `modules/fleet.nix` imports the existing unstable Home Manager only for the desktop capability; stable desktop composition is rejected. Unused stable HM was removed, **not stable Nixpkgs**. `useGlobalPkgs` and `useUserPackages` keep the host's package universe and NixOS-managed user profiles. There are no standalone HM outputs, package overlays or new cache trust. Inputs are named `home-manager` and `zen-browser`, with default-branch GitHub URLs and unstable follows links; `flake.lock` alone pins their revisions. Zen is a normal flake input, but its recipe is still instantiated with the host's `pkgs` instead of upstream's separately imported set.
- `terminal.nix`, `editor.nix`, `browser.nix`, `agents.nix` and `bitwarden.nix` own the approved app preferences; `fingerprint.nix`, `wifi.nix` and `utilities.nix` own their corresponding services, credentials and state.

New choices: dwindle tiling, US keyboard layout, natural touchpad scrolling/tap-to-click, three-finger workspace swipe, 4/8-pixel inner/outer gaps, 8-pixel corners, opaque windows and no blur/shadow. Noctalia uses built-in dark Catppuccin and an auto-hiding top bar. Ghostty and Zen replace Foot and Firefox; approved supporting tools are listed below. No wallpaper, external theme templates, plugins, clipboard history, shell telemetry or online shell content is enabled. The shell/display defaults remain fresh, while the requested application palettes reuse OLED Graphite. Neither palette is an **ICC/HDR calibration**.

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
| Ghostty 1.3.1 / Herdr 0.8.2 | Native HM modules; OLED Graphite, JetBrainsMono Nerd Font, opaque terminal, Herdr as command; Ctrl+A prefix, Zsh default, restored sessions/agent indicators. Disable Herdr release fetching; review its mutable session/integration state before reuse |
| Zed 1.17.2 | Native HM settings/theme/LSPs; OLED Graphite and JetBrainsMono Nerd Font for UI/buffer/terminal, telemetry/update disabled. Nix formatting uses the repository's official `nixfmt -`, not Alejandra. Settings are declarative, not writable through Zed's settings UI |
| Zen 1.22b | Current privacy/search/theme policies, default HTTP(S)/HTML handler. Retain pinned Bitwarden, uBlock Origin, YouTube Enhancer, SponsorBlock, Proton VPN and SimpleLogin extensions; no profile/vault/credential copying. Browser/extension updates require reviewed source/XPI pin updates |
| Pi 0.85.1 | Native HM settings and package; pinned extension manifest/lock and Herdr hook, project trust **ask**, rewind restoration **ask**, no automatic restore on resume/fork/clone. Existing provider defaults retained; OAuth/API credentials stay mutable and private in the existing home |
| Bitwarden 2026.8.0 | Desktop/CLI and local SSH socket routing. Preserve forwarded agents in inbound SSH sessions; disable competing GCR SSH agent, not Secret Service. The app still owns vault unlock, enabling its SSH agent/browser integration and its own autostart |

Only the patched **JetBrainsMono Nerd Font** package is explicitly installed for these apps; the regular JetBrains Mono package is removed. It supplies prompt/developer icons, while native **Noto Color Emoji** fallback remains separate. Font-family/config checks do not establish every glyph's rendering in a live session.

ThinkPad also gets **nh 4.4.2** through `modules/nh.nix`, with the observed `/home/marcos/projects/infra` checkout as its default flake and automatic cleanup disabled. It is not enabled on Dino or either server. See [nh operation boundaries](operations.md#thinkpad-nix-helper-nh); it does not replace canonical checks or commissioning.

The current Pi extension set needs Claude Code and Cursor CLI as provider dependencies; only those two unfree package names are allowed on the desktop. Standalone Claude/Cursor settings/hooks were not imported. Pi's store-backed settings cannot persist `/settings`, model saving or `pi install`; modify declarative settings instead. Updating Herdr/Pi requires reviewing the vendored hook and extension compatibility, not letting an updater overwrite store-backed files. No provider authentication or extension runtime was tested.

Zen's SponsorBlock/YouTube Enhancer settings exports live under `~/.config/sponsorblock/` and `~/.config/youtube-enhancer/` for **manual UI import**; the browser does not automatically consume them. The reused Bitwarden extension's self-hosted endpoint is unchanged, not a newly verified server. Extension/vault settings may require UI acceptance; never weaken TLS to make them connect.

Approved additions: Nautilus, File Roller/GVfs/UDisks, Papers, Loupe, Simple Scan, btop, pavucontrol, NM connection editor, Bluetooth, KDE Connect, and Zsh/Starship/fzf/zoxide/ripgrep/fd/bat/eza. Preserve the current Git identity and safe zoxide/Starship hook ordering. **No media player**, second shell/polkit/notification agent or blanket Thunderbolt authorization was added. The NM editor package also contains nm-applet, but its packaged autostart is masked: Noctalia owns the agent. KDE Connect's packaged autostart is similarly masked in favor of its one HM session service. Native XDG/desktop-file builders create only these two `Hidden=true` overrides; other autostarts stay mutable and collisions still block activation.

KDE Connect opens TCP/UDP **1714–1764**; Avahi discovery opens UDP **5353**, on ThinkPad only. Pair only intended devices and review this exposure on public/campus networks. Bluetooth is initially off; no devices are paired automatically. CUPS listens on localhost only with no shared queues or CUPS firewall opening. The existing Epson ET-3850 endpoint is `ipps://192.168.4.20:631/ipp/print`; it was reviewed in the previous configuration, **not contacted or certificate-verified**. IPP capabilities are queried only when its native queue service later runs. Scanner discovery uses sane-airscan, not an invented scanner URI. Verify printer address/TLS, printing and scanning during authorized acceptance.

## Wi-Fi credentials

Native `networking.networkmanager.ensureProfiles` generates profiles in `/run/NetworkManager/system-connections` with root-only permissions. A root service prepares `/run/fleet-wifi-environment/credentials.env` (directory `0700`, file `0600`) from root-only SOPS files. It escapes both systemd quoting and GLib keyfile syntax; credentials never enter Nix values, the store, command arguments or logs. Do not persist `/run` outputs.

- **MN-Home:** reuse encrypted `wifi-psk` and existing profile UUID; autoconnect enabled. `psk-flags = 0` makes it system-owned, not dependent on a desktop secret agent. The old file-secret agent and its Noctalia contention patch are not copied.
- **SenecaNET:** **not provisioned yet**. `fleet.wifi.senecaSopsFile = null` contributes a commissioning blocker and emits no incomplete campus profile. The prepared policy is PEAP with MSCHAPv2, `/etc/ssl/certs/ca-certificates.crt`, certificate domain suffix **senecapolytechnic.ca**, empty anonymous identity, and username **before `@`**. No credential or server certificate was observed. Once provisioned, initial connection is deliberate (`autoconnect = false`).

For campus provisioning, follow [Fill the SenecaNET placeholders locally](../secrets/README.md#fill-the-senecanet-placeholders-locally). The separate **`secrets/hosts/thinkpad-senecanet.yaml`** already contains encrypted replacement markers for **`seneca-identity`** and **`seneca-password`**, using the existing public recipients without touching the password/PSK file. Replace both through a private SOPS editor, then select the reviewed file with `fleet.wifi.senecaSopsFile`. Until then the option stays null; even if selected early, the runtime adapter rejects the markers rather than delivering dummy credentials. Do not use trailing-newline literal blocks, credentials in shell arguments/chat or plaintext repository files. Run `just secret-check` before staging and `just check` afterward. The template manifest test can pass on markers: it validates key selection, not credential usability or decryption. No review flag is bypassed.

Before activation, review duplicate/stale NetworkManager profiles (including the old MN-Home UUID/agent-owned flags) and back up/reconcile them deliberately. Do not blanket-delete profiles. On campus, confirm the current CA/name policy with Seneca IT and test certificate rejection before acceptance; **never select “no CA certificate,” suppress server-name checks or accept an unexplained certificate**. Indexed official instructions were available; direct page access returned 403. PEAP/MSCHAPv2 depends on this TLS validation to protect credentials. No Wi-Fi connection or SOPS decryption occurred here.

## Mobile and docked displays

Observed on **2026-09-09**: ThinkPad T14 Gen 3, Intel i915 `8086:46a6` at PCI `0000:00:02.0`; `eDP-1`, Chimei Innolux `0x143F`, **1920×1200 @ 60.003 Hz**, scale 1. It was the only connected output. A Razer Core X was listed by Bolt but disconnected; no NVIDIA PCI device or Samsung EDID was available. Historical RTX 3070/G93SC references are not newly verified hardware facts.

- Mobile: keep the internal panel enabled, scale 1, SDR/sRGB, 8-bit, VRR off.
- Any other output: preferred mode, automatic placement, scale 1 and the same conservative SDR policy. No guessed Samsung connector, refresh, luminance, HDR metadata or ICC path. The internal panel is not automatically disabled when docking.
- GPU selection remains automatic. No unstable `/dev/dri/cardN` pin, PRIME bus IDs, global NVIDIA environment or NVIDIA driver selection. Ordinary Intel support remains the working baseline, not a claim that an eGPU already works.
- Existing Bolt authorization is preserved; no wildcard authorization or new device enrollment. Rendering GPU and connector-owning GPU can differ. A future multi-GPU policy must include the GPUs needed for all connected displays, not force Intel in a way that hides eGPU connectors.

Before an NVIDIA/Samsung profile, obtain the live PCI ID/model, driver/kernel compatibility, external EDID/modes, actual connector and physical cable/dock route. Verify bandwidth/DSC and measured display behavior before choosing maximum refresh + 10-bit/HDR or fullscreen-only VRR. Ten-bit alone is not HDR; OLED VRR flicker is not eliminated by a compositor setting. Test cold docked login and undocked login first. Do not assume unplugging an active eGPU is safe or seamless; close affected applications/log out for initial disconnect tests. This follow-up needs the actual hardware, not speculative driver flags.

## Kernels and Intel driver

Keep **`i915`** for the observed Alder Lake-P GPU; the hardware's Iris Xe branding does not mean the newer Linux `xe` driver is preferable. No experimental force-probe, GPU blacklist, NVIDIA driver or kernel tuning is added. `modules/kernel.nix` selects stock `linuxPackages_latest` from each host's own locked track: **7.2.4 ThinkPad/Dino; 7.2.3 Racknerd/Bastion**. These are the latest available in those pins, not a claim every track packages kernel.org's newest patch.

OpenZFS **2.4.4** declares 7.2 support; Bastion's actual 7.2.3 kernel/ZFS module and initrd derivations evaluate with compatibility guards intact. This is **not a kernel/module build, pool import or boot test**. Future updates must retain a supported pair, major 7 and host-track isolation; they must fail rather than allow a broken ZFS module or silently cross to 8.x. Follow kernel EOL, retain recovery generations and check ESP capacity before boot acceptance.

## Fresh configuration and durable state

Home Manager manages generated Hyprland Lua, Ghostty/Herdr/Zed settings and themes, Pi settings/extensions, shell configuration/MIME defaults and the shell's **new** `~/.config/fleet-desktop/noctalia/config.toml`. The Noctalia service uses its supported `NOCTALIA_CONFIG_HOME`, `NOCTALIA_STATE_HOME` and `NOCTALIA_DATA_HOME` overrides. Its state and data are under:

- `~/.local/state/fleet-desktop/noctalia/`
- `~/.local/share/fleet-desktop/noctalia/`

The service does not read/delete old `~/.config/noctalia`, `~/.local/state/noctalia` or `~/.local/share/noctalia` settings/plugins. It does not change other applications' XDG paths. Normal `noctalia msg …` IPC still targets the current Wayland session. To start/restart the intended shell later, use its user service rather than launching a second default-profile instance.

The new profile can still acquire GUI overrides in `settings.toml`; those override the declarative base. For reproducibility, put accepted choices in the module and deliberately reconcile corresponding GUI overrides after backup. Do not automatically remove state to enforce a theme. Only the explicitly requested declarative app preferences/public assets were copied. Browser/vault/keyring profiles and credentials were neither read into Git nor migrated or erased; applications may naturally use their existing private profiles.

`/home` is already a separate early-mounted durable filesystem. No duplicate impermanence binds for configuration, shell state, user PipeWire state or `~/.local/share/keyrings` are necessary. These paths are persistent user data, not backups. New scoped system persistence covers `/var/lib/fprint` (`0700`), `/var/lib/AccountsService` (`0700`), `/var/lib/noctalia-greeter` (greeter-owned `0750`), `/var/lib/bluetooth` (`0700`) and `/var/lib/cups` (queues/PPDs). Caches and print-job spool remain ephemeral; finish pending jobs before reboot/transition. Preserve existing state with correct ownership during separately authorized migration, not broad home/root copies. Native greeter tmpfiles replaces `greeter.toml` with the generated system configuration; back up existing greeter settings/state first.

## Pre-activation and acceptance checklist

1. Preserve console/recovery access and the previous generation; resolve [existing-host transition gates](hosts.md) and [SOPS identity/password delivery](../secrets/README.md). A working old login is not proof the candidate will decrypt the password.
2. Review the current Home Manager generation, unmanaged dotfiles, legacy `hyprland.conf`/Lua/includes, Ghostty/Herdr/Zed/Pi/shell/MIME configs, Bitwarden/old desktop services/autostarts and systemd user overrides. Home Manager collision detection is retained: no `force`, automatic backup-renaming or user-file deletion. Back up and resolve any collisions deliberately before authorized activation. Stop competing shells/lockers as part of a reviewed session transition, not by blindly disabling arbitrary services.
3. Verify the new Noctalia profile paths are unused or contain only intended new state. Review the fresh keyboard/layout/bindings. GUI settings must not accidentally disable locking. Review fingerprint enrollments and password/keyring behavior, provision missing campus ciphertext, and reconcile old NM profiles/agents. Noctalia may still prompt for unknown networks; declarative home/campus profiles use system-owned runtime secrets.
4. `nix develop --no-update-lock-file -c just fmt`, then `nix develop --no-update-lock-file -c just check`. Both-track infrastructure fixtures remain; desktop policy/activation tests cover unstable and actual ThinkPad. Native binaries check generated Hyprland/Noctalia/Ghostty configs, TOML/JSON parsers inspect the other settings, Zen's wrapper/desktop entry is built, font families and nh help/version are checked, and offline Wi-Fi/manifest tests check escaping, marker rejection and encrypted-key selection. These do not start a graphical session, decrypt credentials or build/boot a full machine.
5. `fleet.desktop.reviewed` stays **false** until a real review of login, PAM locking/sleep, portals, audio and mobile display behavior is recorded. It is not NVIDIA/HDR certification and must not be set just to obtain an activation. Arrange any initial target test as a separately authorized commissioning step, retaining all bootstrap and recovery protections. After genuine commissioning, `just ready thinkpad` and `just build thinkpad` are additional local checks, not deployment permission.
6. During separately authorized target acceptance, test password/fingerprint login, empty/wrong-password rejection without a successful scan, reader failure/docked password fallback, sudo and unchanged SSH/console recovery, logout/service lifecycle, lock/unlock and failed authentication, idle display-off/wake, lid/suspend/resume with the lock held, battery behavior, microphone/speaker/headphone switching, notifications/polkit, keyring/network prompting, browser file chooser and screencast/screen sharing. Review `hyprctl configerrors` and user journal diagnostics without publishing sensitive desktop content. Test external display appearance/disappearance separately; never treat the internal-panel test as eGPU/HDR acceptance.

See [ADR 0008](adr/0008-native-desktop-and-kernels.md), the original [ADR 0007](adr/0007-thinkpad-desktop.md), [pinned API research](research.md#native-desktop-apps-authentication-wi-fi-and-kernels--2026-09-09) and [validation scope](validation.md). All fleet readiness flags and the no-provisioning boundary remain intact.
