---
name: thinkpad
description: "The thinkpad host: the operator's Linux laptop, its LUKS disk with TPM2 unlock and Limine Secure Boot, power and battery policy, the Linux desktop role it runs (Umbriel, Noctalia, Home Manager, Wi-Fi, printing, the desk monitor), the eGPU gaming session (Steam in gamescope on a second seat), the link to the operator's phone (KDE Connect, adb, scrcpy, the phone as a webcam), its home backups to bastion, remote builds on bastion, and how it is reinstalled. Use before touching modules/hosts/thinkpad, modules/desktop.nix, umbriel.nix, noctalia.nix, wifi.nix, printing.nix, odyssey.nix, gaming.nix, phone.nix, or reinstalling the laptop, and when the gaming session, the eGPU or the NVIDIA driver misbehaves."
---

# ThinkPad

[modules/hosts/thinkpad/](../../../modules/hosts/thinkpad/) is an Intel ThinkPad on Thunderbolt.
It runs the `desktop` role, `remote-builds` (every build goes to bastion over the tailnet, with
`nix-build-ssh-key`, whose public half is `builderKeys.thinkpad` in
[builder.nix](../../../modules/builder.nix); `max-jobs = 0` keeps the laptop from building
itself, so without bastion only substitutes work) and `backup-home`.

## Disk, unlock and boot

The NVMe holds the boot partition and the LUKS state partition ([storage.nix](../../../modules/storage.nix));
the root is wiped at every boot like the servers', and `/home/marcos` survives under `/persist`
([access.nix](../../../modules/access.nix)). There is no disk swap: zram only, and no hibernation.
LUKS opens with a TPM2 token sealed to PCR 7 and a PIN, the passphrase as fallback, and Limine is
signed with the sbctl keys in `/var/lib/sbctl`, carried across reinstalls. Unlike bastion, which
stays home, the laptop travels with the builder key, the backup password and signed-in sessions on
its disk, so the PIN keeps a stolen laptop locked: PCR 7 alone would hand the key to anyone who
boots the genuine signed loader. The NixOS installer is unsigned, so a reinstall turns Secure Boot
off in the firmware, installs with the carried keys, turns it back on, then seals the new LUKS
header:

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes /dev/disk/by-partlabel/disk-os-state
```

A reinstall follows the [deploy skill](../deploy/SKILL.md#install), opening the old LUKS partition
first; wiping it destroys the old LUKS header and with it everything the old install held.

## Desktop

The role is one file per concern, each setting its NixOS and Home Manager halves: the base in
[desktop.nix](../../../modules/desktop.nix) (Home Manager as a NixOS module, NetworkManager,
Bluetooth, PipeWire, UPower, power profiles, the apps), [umbriel.nix](../../../modules/umbriel.nix)
(the compositor session from nixpkgs' module, and `programs.umbriel.settings`, a config layered
over Umbriel's packaged `config.toml`: tables merge by key and the last file wins, so only changes
to stock are written; hosts and odyssey.nix add their outputs; `Mod + /` lists the keybinds),
[noctalia.nix](../../../modules/noctalia.nix) (bar, launcher, notifications, lock, idle, the polkit agent, the greeter,
whose output layout is derived from Umbriel's positions; apps it launches run as their own systemd
units, so a shell restart does not take them down; the `desktop-config-HOST` check fails on any
key either program's validator rejects or warns about),
[wifi.nix](../../../modules/wifi.nix), [printing.nix](../../../modules/printing.nix) and
[odyssey.nix](../../../modules/odyssey.nix) (the desk monitor's mode and DDC brightness). Looks
follow the [desktop skill](../desktop/SKILL.md). The tailnet client accepts bastion's subnet routes
so the LANs stay reachable away from home; at home MN-Home is the Home LAN, which bastion does not
advertise, so the laptop's own LAN stays on-link and only the printer, on the IoT LAN, goes
through bastion. Bitwarden's desktop app is the SSH agent
(`~/.bitwarden-ssh-agent.sock`), started at login.

Claude Code runs under the same managed settings as the mac ([claude.nix](../../../modules/claude.nix)),
written to `/etc/claude-code`, with its Bash sandbox on bubblewrap and socat. Claude Code's
seccomp helper (`apply-seccomp`, the first process of every Bash command) refuses a command any
new Unix socket, but it is Claude Code's to ship or drop, so the managed `filesystem.denyRead` in
claude.nix also hides the sockets one by one: `/run/user` (the session D-Bus, the keyring, Wayland), the system D-Bus, `/run/systemd`
(resolved, the journal, the varlink services that ask polkit), nscd, which like resolved would
resolve any name outside the network namespace, tailscaled, CUPS, Xwayland, Bitwarden's agent
and the Nix daemon, whose fixed-output builds reach the network outside the sandbox. It is a deny
list, so a daemon added later needs its socket added there. `/persist` is hidden too, since it
holds a second path to the whole home. As on the mac, `nix` commands that need the daemon run
outside Claude's sandbox.

That sandbox covers Bash only, so on the Linux laptops the `claude` command itself is a jail
(`jail` in claude.nix) around everything Claude Code starts: its own process, the MCP and language
servers, hooks and plugins. bubblewrap gives it an empty home holding only Claude's state, the Git
identity and the working directory (the whole repository and its Git directory when it is in one,
so subdirectories and linked worktrees keep working; a Git directory that is neither the
repository's own `.git` nor a worktree pointing back at it is not bound), and an empty `/run` with only the read-only
paths in `readOnly` and the DNS stub, so no socket under `/run` or the home exists inside. Only the environment
variables in `keptEnv` pass, so a credential exported in the launching shell stays out, and
`CLAUDE_CONFIG_DIR` keeps `.claude.json` inside `~/.claude`, where the lock that orders two
sessions' writes is shared; the wrapper moves an old `~/.claude.json` there once. pasta gives it a private
network namespace that reaches out through NAT, which closes services bound to the host's loopback
and abstract sockets. A service bound to every address stays reachable through the host's own
tailnet or LAN address, which pasta delivers on `lo` past the firewall, and the LAN, the tailnet
and the internet stay reachable; only Bash is held to the allowlist. The wrapper refuses to start
in a directory that holds or sits under a path the jail hides, resolved through symlinks. The jail
keeps the terminal for job control, so `dev.tty.legacy_tiocsti` is 0 on these hosts (claude.nix):
nothing inside can push input to the shell `claude` returns to. It costs what needs the session or the host's loopback: pasting an image, desktop
notifications, the editor integrations and a browser sign-in that calls back to a local port.
Claude Code's Bash sandbox nests inside it, which is why the jail leaves user namespaces enabled.
The jail has no Nix daemon either, so a `nix` command typed with `!` in Claude falls back to a
throwaway store in the jail's home; Nix runs from a terminal outside Claude.

Idle locks, turns the screen off and suspends on the timers in
[noctalia.nix](../../../modules/noctalia.nix), unless an app holds an idle inhibitor, as a browser
does while a video plays; on battery two earlier timers there turn the screen off and suspend
sooner. On battery `power-profile-ac` switches to
power-saver and caps the panel brightness, and restores the previous profile and brightness on AC;
the battery charges to 90% and resumes at
85%. The home backup and the btrfs scrub ([desktop.nix](../../../modules/desktop.nix)) start on
AC only. Shutting the lid removes the built-in panel from the desktop, docked or not, and windows move
to another display until it opens; undocked on AC that leaves no display until the lid opens or the
idle timer suspends, and the idle lock still engages with no output, so opening the lid shows the
lock screen. Shutting it suspends on
battery only: on AC the idle timer does, since a monitor that sleeps drops off DRM and logind would
read that as an undock.

## Gaming

[gaming.nix](../../../modules/gaming.nix) runs Steam's Deck interface in gamescope on an NVIDIA
card in a Thunderbolt enclosure, beside the Umbriel session instead of in it. The card, and while
gaming the Keychron receivers, belong to a second logind seat, so Umbriel never opens the card and
keeps the built-in panel, keyboard and trackpad. `gaming.service` is that session; `gaming`,
`Mod + G`, Noctalia's session entry and Steam's Switch to Desktop all only start or stop it;
the unit's own stop asks Steam to shut down and waits for it, so a running game is not cut off
mid-save. A reboot or poweroff is the exception: logind stops the session's processes at the same
time as the unit, so leave the session first.
Its handover moves the monitor to DisplayPort over DDC and back to whatever input was active,
holds the performance profile and a sleep inhibitor, and runs `scx_lavd`.

It starts only from an unlocked session, never on plug: the unit runs as `marcos` without a login,
so starting on plug would hand an unlocked session to whoever holds the enclosure. For the same
reason a running session is unlocked: the idle lock covers the Umbriel seat only, and it fires
during play because that seat sees no input. Leaving the desk means leaving the session first.

The NVIDIA driver freezes the kernel when the card leaves while it is bound, even idle, and a
frozen removal blocks every rescan and the next shutdown; only a forced reboot clears it. So the
card sits on the PCI bus only while the session runs: a udev rule removes it whenever it appears
otherwise, the handover rescans on start, and on stop it detaches the card and unloads the NVIDIA
modules. The cable is safe to pull whenever no session runs, and never during one. For the same
reason the Umbriel session loads Mesa only: a desktop program that opens the NVIDIA device nodes
keeps the old card alive and the next start fails with `Failed to allocate NvKmsKapiDevice`.

gamescope gets the card and the mode by argument, since it otherwise picks the Intel Vulkan device
and a lower mode; adaptive sync is off because it glitched on this card, and HDR is off because the driver
flickers with it above 2560x1440@120 and 10-bit at this mode does not fit the DisplayPort link
uncompressed. Every Proton game inherits the unit's DLSS settings: the game's DLSS is replaced
by the current one and pinned to the transformer preset the card affords, since the newer
presets cost a 30-series card far more. gamescope's
own output is filed under the session scope, not the unit: read a start with
`journalctl -b --since -1min`, not `-u gaming.service`. The proprietary NVIDIA module and the
`SIGKILL` on stop are `shortcut:` entries in the module. MangoHud draws frame rate,
frame times, load, temperatures and memory on every game through the unit's environment; gamescope's mangoapp overlay did not draw
on this card.

bastion builds Steam's 32-bit closure, so it is advertised as an `i686-linux` builder
([builder.nix](../../../modules/builder.nix)). The NVIDIA module is built against the laptop's
kernel, the newest nixpkgs has, so a kernel the driver does not build against yet blocks every
thinkpad build until the kernel is held back.

## Phone

[phone.nix](../../../modules/phone.nix) links the Linux laptops to the operator's phone, `grafite`
on the tailnet. KDE Connect listens on the tailnet interface only, so the phone is added by the
laptop's tailnet name: its broadcast discovery does not cross the tailnet. adb reaches the phone's
Wireless debugging over the tailnet through the grant in the
[OpenTofu project](../opentofu/SKILL.md); the port is new each time Wireless debugging is switched
on, so `adb connect` is repeated, while `adb pair` is once per laptop. While Wireless debugging is
on, the laptop's adb key is a shell on the phone from anywhere on the tailnet, and the grant
reaches every other unprivileged listener on the phone too: both accepted risks.

Two v4l2loopback devices exist: one feeds the AndroidConnect panel's embedded preview, the other
is the webcam `phone-camera` fills from the phone's camera with scrcpy, for as long as it runs.
The module is out of tree and built against the laptop's kernel, so like the NVIDIA one it can
block a build after a kernel bump. AndroidConnect is a community Noctalia plugin with a Python
companion; opening its panel starts mirroring, wakes the phone and forwards its audio, and its
code needs reading on a bump ([tailnet skill](../tailnet/SKILL.md)).

The adb key and the KDE Connect identity are home secrets
([_home-secrets.nix](../../../modules/_home-secrets.nix)): out of the home backup and of Claude's
reach, so a restored home pairs again. adb's local server answers any local process; it has no
loopback guard because `marcos` has no pinned uid.

## Backups

`restic-backups-home` sends `/home/marcos` every 6 hours, skipping a run that falls on battery, to the append-only server on bastion
([backups skill](../backups/SKILL.md)) with `backups/thinkpad-password`, never the household key;
only root on the laptop may reach that port. Identity keys (SSH, GnuPG, sops, gh, adb, KDE Connect), the keyring,
caches and the Bitwarden socket stay out, and so do Steam's installed games, shader caches and
downloads, which Steam fetches again. App data stays in, browser and messenger sessions
included, so a restore brings back a signed-in desktop, and Steam's Proton prefixes, where games
without Steam Cloud keep their saves; bastion holds the password too, so whoever controls bastion
can read those sessions.
