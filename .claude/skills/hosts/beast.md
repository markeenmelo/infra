# Beast

[modules/hosts/beast/](../../../modules/hosts/beast/) is the operator's gaming desktop: an ASRock
Z690 board, an Intel 12th-gen CPU with its iGPU off in the firmware, and an NVIDIA card. It runs
the `desktop` role ([desktop skill](../desktop/SKILL.md)), builds for itself with bastion's cache
as a substituter (`cache-client` in [builder.nix](../../../modules/builder.nix)), builds for the thinkpad
(`build-host`, which trusts only its build key; clients prefer beast while it is awake), and is an
operator machine like the thinkpad (`operatorNames` in
[opentofu.nix](../../../modules/opentofu.nix)), so it reaches the cache and the OpenTofu state.
The card runs NVIDIA's open kernel module, which can lag the newest kernel as ZFS does on bastion, so [kernel.nix](../../../modules/kernel.nix) boots the newest series that module builds for; VRAM is preserved across suspend, since the idle timer
suspends the desktop; Steam comes from the `gaming` module ([gaming.nix](../../../modules/gaming.nix)),
its state under the preserved home, and the library on `/games` is added once in Steam's storage
settings.

## Disk, unlock and boot

The smaller NVMe is the `os` disk of [storage.nix](../../../modules/storage.nix), with the root
wiped at every boot. Limine is signed with beast's own keys (the `secure-boot` module,
[secure-boot.nix](../../../modules/secure-boot.nix)). Once Secure Boot is on, LUKS opens with a
TPM2 token sealed to PCR 7 without a PIN, the passphrase kept as fallback, and asks for the
passphrase until then, since with Secure Boot off PCR 7 is the same for any loader. The keys are
enrolled with Microsoft's CA kept, which the RTX 3070's option ROM needs, so as on bastion PCR 7
also matches under a Microsoft-signed loader that does not measure what it boots, and a stolen box
can unseal the key; accepted over a TPM PIN, since the desktop stays home. The keys are carried
across reinstalls but not backed up, since beast runs no backups; losing them means making and
enrolling new ones.

Keys for a host that has none are made on it straight into the preserved path, before signing is
turned on; sbctl's landlock sandbox refuses any path but its own, hence the flag:

```sh
sudo nix shell nixpkgs#sbctl -c sbctl create-keys --disable-landlock -e /persist/var/lib/sbctl/keys -d /persist/var/lib/sbctl/GUID
```

The first deploy that turns signing on installs Limine before Preservation mounts
`/var/lib/sbctl`, and the installer reads the keys only there and ignores a failed `sbctl sign`,
so the keys are bound in by hand first and the signature is checked before the firmware enforces
it. Then the firmware is put in setup mode, the keys enrolled beside Microsoft's, Secure Boot turned
on, and the TPM sealed:

```sh
sudo mkdir -p /var/lib/sbctl && sudo mount --bind /persist/var/lib/sbctl /var/lib/sbctl
just deploy beast                         # from the operator's machine
sudo sbctl verify                         # BOOTX64.EFI signed; kernels are checked by hash instead
systemctl reboot --firmware-setup         # Security > Secure Boot: custom mode, reset to setup mode
sudo sbctl enroll-keys --microsoft
systemctl reboot --firmware-setup         # turn Secure Boot on
sudo sbctl status                         # Secure Boot enabled
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-os-state
```

A firmware update changes PCR 7, so LUKS asks for the passphrase again until the token is
resealed with the last command plus `--wipe-slot=tpm2`.

## Fans and lighting

[case.nix](../../../modules/hosts/beast/case.nix) loads `nct6775` for the board's Nuvoton NCT6798,
which exposes the fans and their PWM outputs. OpenRGB runs as a root server for the board's
Polychrome USB controller, the DRAM, the card and the AIO cooler; its SDK port answers without
authentication, so a loopback guard lets only root and `marcos` reach it, and its profiles stay in
`/var/lib/OpenRGB`.

The power profile is beast's one switch, set from the bar or by GameMode: `beast-mode` follows it,
running fan2go with the gaming curve and rainbow lighting under `performance`, and turning the
lights off and stopping fan2go under any other profile. On exit fan2go hands the channels back to
the firmware's automatic mode, so the firmware's own curve, set to silent, is the quiet mode and
also runs the fans at boot or whenever fan2go is down. The gaming curve follows the CPU package
temperature and drives the three connected channels alike, since which header feeds the AIO pump is
unknown, never below 38%.

## Network and wake

beast is wired: [hardware.nix](../../../modules/hosts/beast/hardware.nix) turns the Wi-Fi radio
off at every boot (the bar turns it back on until the next one), and NetworkManager arms
magic-packet Wake-on-LAN on the wired connection, so `nix run .#wake -- beast` powers it on from
the Home VLAN, suspended or off. Waking from off also needs the firmware's PCIe power-on enabled
and its ErP / deep sleep disabled.

## Display

[display.nix](../../../modules/hosts/beast/display.nix) drives the Odyssey G93SC at 5120x1440 and
240 Hz over DisplayPort, which the thinkpad's HDMI cannot reach, so it overrides the 120 Hz default
of [odyssey.nix](../../../modules/odyssey.nix). HDR is always on, as on the thinkpad; VRR engages for
fullscreen windows and always for Steam games. The 10-bit render depth and the EDID color profile
mapping untagged SDR to sRGB apply whenever the panel runs SDR.

## Games drive

The larger NVMe holds the game library on LUKS and ext4 at `/games`, outside disko like bastion's
pools, so an install never formats it. `/etc/crypttab` opens it in stage 2 with the keyfile
`/persist/var/lib/luks/games.key`, which is in `fleet.carry`, so a reinstall keeps the library
readable; losing the keyfile loses the library, which Steam downloads again. Both mounts are
`nofail`: a missing drive or key leaves the desktop booting without `/games`.

Before the first install the keyfile goes into the directory `enroll` made, since `install`
refuses an identity that lacks a carried path:

```sh
install -d -m 700 ~/.config/sops/enroll/beast/persist/var/lib/luks
(umask 077; head -c 64 /dev/urandom > ~/.config/sops/enroll/beast/persist/var/lib/luks/games.key)
```

Once, after the first boot, format the drive; this wipes it:

```sh
sudo cryptsetup luksFormat --type luks2 --batch-mode --key-file /persist/var/lib/luks/games.key /dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b416db901
sudo systemctl start systemd-cryptsetup@games.service
sudo mkfs.ext4 -L games /dev/mapper/games
sudo systemctl start games.mount
sudo chown marcos:users /games
```

A reinstall follows [operating: deploy](../operating/deploy.md#install) and touches only the `os` disk. The NixOS installer is unsigned, so Secure Boot is turned off in the firmware first; the install signs Limine with the carried keys, Secure Boot goes back on, and the new LUKS header is sealed with the `systemd-cryptenroll` line above.
