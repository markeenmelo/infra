# Inspiron

[modules/hosts/inspiron/](../../../modules/hosts/inspiron/) is Ian's Dell Inspiron 14 2-in-1 (AMD
Ryzen 5000, Barcelo graphics, AX210 Wi-Fi), used for Minecraft and mostly on AC. It runs the
`kiosk` role ([kiosk.nix](../../../modules/kiosk.nix)), which powers it off at 13:00 and 20:00 every day, and on waking from a suspend that spanned either time: greetd logs `ian` straight into gamescope
running Prism Launcher, and starts it again when it exits; `ian` has no sudo, `marcos` and
`deploy` are the fleet's accounts, the CPU governor stays on `performance`, and Bluetooth is on for a mouse or controller, paired from an SSH session with `sudo bluetoothctl`.

## Minecraft

Prism launches the instance `fo` straight away: the Fabulously Optimized modpack, fetched from
Modrinth and pinned by `packHash` with nix-minecraft's fetcher, minus e4mc, which would open a LAN
world to the internet. It runs on GraalVM CE with a 4 to 6 GB heap. At every boot and deploy,
`minecraft-instance` links the pack's mods and resource packs into the instance read-only, writes
`mmc-pack.json` and the settings keys Nix declares into Prism's files while keeping the keys Prism
adds, and copies the pack's configs only where none exist, since the mods rewrite them. A bump
therefore moves the mods, game and loader versions together on the next deploy. To bump: set
`version` and `url` from Modrinth, the Minecraft and loader versions from its index, and an empty
`packHash`, build, and paste the hash the build prints. The Microsoft sign-in is the one step by
hand, and the tokens Prism keeps in `accounts.json` stay out of Nix.

## Disk and boot

`plain-storage`: an ext4 root on LUKS, never rolled back, so everything Ian keeps stays. Limine is
signed with inspiron's own keys (the `secure-boot` module), and LUKS opens with a TPM2 token sealed
to PCR 7 without a PIN, the passphrase kept as fallback, on the same terms as beast's: Microsoft's
CA stays enrolled so the firmware's own signed drivers still load, which also lets a stolen laptop
unseal the key under a Microsoft-signed loader; accepted, since a PIN would stop Ian's boot.

With no Preservation the keys live at sbctl's own path, so they are made there and the first deploy
signs Limine with no bind mount. Dell's firmware calls setup mode Expert Key Management, under
Secure Boot:

```sh
sudo nix shell nixpkgs#sbctl -c sbctl create-keys
just deploy inspiron                      # from the operator's machine
sudo sbctl verify                         # every EFI file signed
systemctl reboot --firmware-setup         # Secure Boot > Expert Key Management: custom mode, delete all keys
sudo sbctl enroll-keys --microsoft
systemctl reboot --firmware-setup         # turn Secure Boot on
sudo sbctl status                         # Secure Boot enabled
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-os-state
```

A firmware update changes PCR 7; reseal with the last command plus `--wipe-slot=tpm2`.

## Network

It joins MN-Kids on the Kids VLAN with its permanent MAC, which the UniFi project fixes to
192.168.20.2 as the client `Dino`, with the passphrase from `kids-wifi-psk`. Its tailnet tag,
`tag:kid`, admits SSH from the admin clients and reaches only bastion's cache and its own telemetry ports. It takes neither the
tailnet's DNS (`--accept-dns=false`) nor an exit node, since the tailnet's resolvers would bypass
the Kids VLAN's content filter and bedtime rule.

## Builds

It never builds: `max-jobs` is 0, so `deploy` builds it on the deploying machine (from the thinkpad,
on bastion) and copies the closure over, and inspiron holds no builder key, which would let a
compromised game write into bastion's trusted store.
