# ThinkPad

[modules/hosts/thinkpad/](../../../modules/hosts/thinkpad/) is an Intel ThinkPad on Thunderbolt.
It runs the `desktop` role ([desktop skill](../desktop/SKILL.md)), `remote-builds` (every build goes over the tailnet to beast or bastion, spread by load against their speed factors, about 2:1 to beast while it is awake, with
`nix-build-ssh-key`, whose public half is `builderKeys.thinkpad` in
[builder.nix](../../../modules/builder.nix); `max-jobs = 0` keeps the laptop from building
itself, so with neither builder reachable only substitutes work).

## Disk, unlock and boot

The NVMe holds the boot partition and the LUKS state partition ([storage.nix](../../../modules/storage.nix));
the root is wiped at every boot like the servers', and `/home/marcos` survives under `/persist`
([access.nix](../../../modules/access.nix)). There is no disk swap: zram only, and no hibernation.
LUKS opens with a TPM2 token sealed to PCR 7 and a PIN, the passphrase as fallback, and Limine is
signed with the sbctl keys in `/var/lib/sbctl`, carried across reinstalls. Unlike bastion, which
stays home, the laptop travels with the builder key and signed-in sessions on
its disk, so the PIN keeps a stolen laptop locked: PCR 7 alone would hand the key to anyone who
boots the genuine signed loader. The NixOS installer is unsigned, so a reinstall turns Secure Boot
off in the firmware, installs with the carried keys, turns it back on, then seals the new LUKS
header:

```sh
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes /dev/disk/by-partlabel/disk-os-state
```

A reinstall follows [operating: deploy](../operating/deploy.md#install), opening the old LUKS partition
first; wiping it destroys the old LUKS header and with it everything the old install held.

