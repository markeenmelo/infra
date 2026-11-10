---
name: thinkpad
description: "The thinkpad host: the operator's Linux laptop, its LUKS disk with TPM2 unlock and Limine Secure Boot, power and battery policy, the Linux desktop role it runs (Hyprland, Noctalia, Home Manager, Wi-Fi, printing, the desk monitor), its home backups to bastion, remote builds on bastion, and how it is reinstalled. Use before touching modules/hosts/thinkpad, modules/desktop.nix, hyprland.nix, noctalia.nix, wifi.nix, printing.nix, odyssey.nix, or reinstalling the laptop."
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
Bluetooth, PipeWire, UPower, power profiles, the apps), [hyprland.nix](../../../modules/hyprland.nix)
(UWSM session, Lua config over the stock one, keybinds; `SUPER + /` lists them),
[noctalia.nix](../../../modules/noctalia.nix) (bar, launcher, notifications, lock, idle, the greeter),
[wifi.nix](../../../modules/wifi.nix), [printing.nix](../../../modules/printing.nix) and
[odyssey.nix](../../../modules/odyssey.nix) (the desk monitor's mode and DDC brightness). Looks
follow the [desktop skill](../desktop/SKILL.md). The tailnet client accepts bastion's subnet routes
so the LANs stay reachable away from home; at home MN-Home is the Home LAN, which bastion does not
advertise, so the laptop's own LAN stays on-link and only the printer, on the IoT LAN, goes
through bastion. Bitwarden's desktop app is the SSH agent
(`~/.bitwarden-ssh-agent.sock`), started at login.

Claude Code runs under the same managed settings as the mac ([claude.nix](../../../modules/claude.nix)),
written to `/etc/claude-code`, with its Bash sandbox on bubblewrap and socat. The sandbox does not
block Unix sockets without Claude Code's optional seccomp helper, which has no documented path
outside an npm install, so the managed `filesystem.denyRead` in claude.nix hides the sockets one
by one: `/run/user` (the session D-Bus, the keyring, Wayland), the system D-Bus, `/run/systemd`
(resolved, the journal, the varlink services that ask polkit), nscd, which like resolved would
resolve any name outside the network namespace, tailscaled, CUPS, Xwayland, Bitwarden's agent
and the Nix daemon, whose fixed-output builds reach the network outside the sandbox. It is a deny
list, so a daemon added later needs its socket added there. `/persist` is hidden too, since it
holds a second path to the whole home. As on the mac, `nix` commands that need the daemon run
outside Claude's sandbox.

Idle locks at 5 min, turns the screen off at 5.5, suspends after 10 on battery and 30 on AC. On
battery `power-profile-ac` switches to power-saver and restores the previous profile on AC; the
battery charges to 90% and resumes at 85%. The lid hides the built-in panel while another display
is connected.

## Backups

`restic-backups-home` sends `/home/marcos` every 6 hours to the append-only server on bastion
([backups skill](../backups/SKILL.md)) with `backups/thinkpad-password`, never the household key;
only root on the laptop may reach that port. Identity keys (SSH, GnuPG, sops, gh), the keyring,
caches and the Bitwarden socket stay out. App data stays in, browser and messenger sessions
included, so a restore brings back a signed-in desktop; bastion holds the password too, so
whoever controls bastion can read those sessions.
