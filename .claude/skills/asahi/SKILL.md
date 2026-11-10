---
name: asahi
description: "The asahi host: the operator's Apple Silicon MacBook running NixOS beside macOS through nixos-apple-silicon, its shared disk and ESP, firmware loaded at boot, the stock Asahi kernel, power and display behaviour, how it builds itself, and how it is reinstalled. Use before touching modules/hosts/asahi, the nixos-apple-silicon input, or reinstalling the MacBook."
---

# asahi

[modules/hosts/asahi/](../../../modules/hosts/asahi/) is the MacBook. It runs the same `desktop`
role as the thinkpad ([thinkpad skill](../thinkpad/SKILL.md#desktop)) and `remote-builds`, which on
aarch64 only sends x86_64 builds to bastion: nothing else builds `aarch64-linux` and
nixos-apple-silicon publishes no binary cache, so it builds itself, kernel included, and CI only
evaluates it. Switch it from its own checkout with `just switch`. It has no home backup. The
desktop's apps that nixpkgs does not build for `aarch64-linux`, Spotify among them, are left out.

## Disk and boot

macOS owns the disk. The Asahi installer, run from macOS with "UEFI environment only", made the
stub container and the ESP; NixOS holds one partition. `fleet.esp` in
[storage.nix](../../../modules/storage.nix) names that ESP, which disko mounts at `/boot` and never
formats, and `disko.devices.disk.os.device` is the state partition itself, LUKS with the fleet's
btrfs inside. Apple Silicon has no TPM, so LUKS opens with the passphrase at every boot, and the
chain (m1n1, U-Boot, Limine) has no Secure Boot. The ESP is small, so Limine keeps 5 generations.
`switch-os` reboots once into macOS.

Apple's peripheral firmware is non-redistributable and this repository is public, so it never
enters the repository or the store: with `peripheralFirmwareDirectory = null` the initrd unpacks
`vendorfw/firmware.cpio` from the ESP, which upstream calls experimental. An Asahi firmware update
is the installer's "Rebuild vendor firmware package" from macOS.

## Kernel, display and power

The stock `linux-asahi` from the input has no DisplayPort alt mode, so external displays use the
HDMI port only. Asahi reads no EDID there, so the Odyssey runs 8-bit sRGB without VRR, every field
set since a later rule changes only the fields it names. `appledrm.show_notch` puts the bar over the
notch, at a scale that divides the panel; `appledrm.hdmi_audio` is a driver option its authors mark
unstable. There is no `platform_profile`, so TuneD's PPD bridge replaces power-profiles-daemon for
Noctalia's power widget and picks power-saver on battery. The panel runs 120 Hz on AC and 60 Hz on
battery: `on_ac()` picks the mode when Hyprland loads its config and `hypr-ac-reload` reloads it when
AC changes. wluma sets the panel brightness from the light sensor.

## Reinstall

Follows the [deploy skill](../deploy/SKILL.md#install) from the nixos-apple-silicon installer ISO,
booted through U-Boot, with Secure Boot and TPM steps skipped: open the old LUKS partition, mount it
read-only, and run the install app. Only the state partition is wiped; macOS, the stub and the ESP
stay.
