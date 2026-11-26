# Beast

[modules/hosts/beast/](../../../modules/hosts/beast/) is the operator's gaming desktop: an ASRock
Z690 board, an Intel 12th-gen CPU with its iGPU off in the firmware, and an NVIDIA card. It runs
the `desktop` role ([desktop skill](../desktop/SKILL.md)), builds for itself with bastion's cache
as a substituter (`cache-client` in [builder.nix](../../../modules/builder.nix)), and is an
operator machine like the thinkpad (`operatorNames` in
[opentofu.nix](../../../modules/opentofu.nix)), so it reaches the cache and the OpenTofu state.
The card runs NVIDIA's open kernel module with VRAM preserved across suspend, since the idle timer
suspends the desktop; Steam comes from the `gaming` module ([gaming.nix](../../../modules/gaming.nix)),
its state under the preserved home, and the library on `/games` is added once in Steam's storage
settings.

## Disk, unlock and boot

The smaller NVMe is the `os` disk of [storage.nix](../../../modules/storage.nix), with the root
wiped at every boot. Secure Boot is off until it gets its own sbctl keys, and until then LUKS asks
for the passphrase at every boot: with Secure Boot off, PCR 7 is the same for any loader, a live
USB included, so a token sealed to it would hand the key to anyone at the keyboard. Once Secure
Boot is on, the header gets a TPM2 token sealed to PCR 7 without a PIN, since the desktop stays
home, the passphrase kept as fallback.

Its sbctl keys live in `/var/lib/sbctl`, preserved under `/persist` and in `fleet.carry` like the
thinkpad's. They are made once on beast, before Limine signing is turned on:

```sh
sudo sbctl create-keys
```

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

A reinstall follows [operating: deploy](../operating/deploy.md#install) and touches only the `os` disk.
