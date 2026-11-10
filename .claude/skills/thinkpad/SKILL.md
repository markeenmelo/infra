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
LUKS opens with a TPM2 token sealed to PCR 7, the passphrase as fallback, and Limine is signed with
the sbctl keys in `/var/lib/sbctl`, carried across reinstalls. The NixOS installer is unsigned, so a
reinstall turns Secure Boot off in the firmware, installs with the carried keys, turns it back on,
then seals the new LUKS header:

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-os-state
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
follow the [desktop skill](../desktop/SKILL.md). Bitwarden's desktop app is the SSH agent
(`~/.bitwarden-ssh-agent.sock`), started at login.

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
