# Inspiron

[modules/hosts/inspiron/](../../../modules/hosts/inspiron/) is Ian's Dell Inspiron 14 2-in-1 (AMD
Ryzen 5000, Barcelo graphics, AX210 Wi-Fi), used for Minecraft and mostly on AC. It runs the
`kiosk` role ([kiosk.nix](../../../modules/kiosk.nix)): greetd logs `ian` straight into gamescope
running Prism Launcher, and starts it again when it exits; `ian` has no sudo, `marcos` and
`deploy` are the fleet's accounts, and the CPU governor stays on `performance`. It pushes metrics and its journal to bastion (`telemetry`, ports 9098 and 3106) like edge, so it shows in Grafana's node-exporter-full and Loki.

## Disk and boot

`plain-storage`: an ext4 root on LUKS, never rolled back, so everything Ian keeps stays. LUKS asks
for its passphrase until Secure Boot and the TPM seal come, as on beast.

## Network

It joins MN-Kids on the Kids VLAN with its permanent MAC, which the UniFi project fixes to
192.168.20.2 as the client `Dino`, with the passphrase from `kids-wifi-psk`. Its tailnet tag,
`tag:kid`, admits SSH from the admin clients and reaches only bastion's cache. It takes neither the
tailnet's DNS (`--accept-dns=false`) nor an exit node, since the tailnet's resolvers would bypass
the Kids VLAN's content filter and bedtime rule.

## Builds

It never builds: `max-jobs` is 0, so `deploy` builds it on the deploying machine (from the thinkpad,
on bastion) and copies the closure over, and inspiron holds no builder key, which would let a
compromised game write into bastion's trusted store.
