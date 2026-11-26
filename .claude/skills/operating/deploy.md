# Deploy

[deploy.nix](../../../modules/deploy.nix) turns every `fleet.hosts` entry into a deploy-rs node
reached by its MagicDNS name as the `deploy` account. That account is root-equivalent: it is a
Nix trusted user so unsigned closures can be copied in, and sudo lets it run any store path's
`activate-rs`, remove the rollback canary, run `clean-generations`, reboot and power off. Its key is therefore a root key on every host and is not the
operator's login key ([_operator-key.nix](../../../modules/_operator-key.nix)): its private half lives only in the operator's
Bitwarden SSH agent, which asks before each use. The other path to root is `marcos`, who logs in
on bastion and the workstations with the login key (`operator-login` in [access.nix](../../../modules/access.nix)) and runs sudo with the
shared password, so root there needs either the deploy key with its Bitwarden prompt or the login key plus the
password. Edge has no `marcos`: `deploy` is the only account it admits.
[server.nix](../../../modules/server.nix) sets `security.sudo.execWheelOnly`, so no service account can run
sudo on a server; `deploy` is in `wheel` there only to run the wrapper, and since `wheel`'s own rule asks for a
password `deploy` does not have, it still runs only the commands listed below. IPv6 stays on host-wide, also for the
sake of deploys: MagicDNS answers with each node's tailnet IPv6 address, and a peer that tries it first
against a host with IPv6 off waits out a connect timeout that can outlast the rollback confirm;
the uplinks refuse IPv6 per link instead. Magic rollback and auto rollback stay on: a profile
that breaks the SSH path reverts after the confirm timeout. `--boot` is the exception: deploy-rs
activates it without the confirm step, so a boot that fails is recovered from the Limine menu. `nix flake check` carries the
deploy-rs schema and activation checks per system. A host without nh (bastion, edge) prints dix's
package diff between the running and the new system at each activation, `--dry-activate`
included, as nh does on the workstations. The `deploy` binary and the activator are
nixpkgs' package, taken from the binary cache; the input supplies only its library.

A host builds itself unless its `nix.settings.max-jobs` is 0 (bastion, which runs the builder
in [builder.nix](../../../modules/builder.nix), the edge and beast); a host that imports
`remote-builds` (the thinkpad) or refuses local builds (inspiron) is built on the deploying machine, which from the thinkpad hands the build to bastion. The deploying
machine receives the whole closure back from bastion; deploy-rs then pushes it with
`--substitute-on-destination`, so the target fetches what bastion holds from its Harmonia cache.
Bastion trusts the admin clients' build keys alone: the edge builds itself, and the tailnet
policy keeps it off the cache ([opentofu skill](../opentofu/SKILL.md)), so a compromised edge
cannot reach bastion's store. A build key is a
trusted user on bastion and whatever it uploads is signed and served to every workstation, so a stolen
build key is root on bastion without the deploy key's Bitwarden prompt. That is accepted: Nix
refuses remote builds from an untrusted user (`you are not privileged to build input-addressed
derivations`), and the key is readable only by root on an admin client.
`remote-builds` makes bastion's cache each workstation's first substituter, so a cleaned store
refills from bastion instead of rebuilding.
CI on `main` reads the cache too: [check.yml](../../../.github/workflows/check.yml) joins the
tailnet as an ephemeral `tag:ci` node, whose only grant is port 5005, fetches what bastion holds
and leaves before it builds, so tailnet minutes stay short and nothing built by CI reaches
bastion. Pull requests never join ([opentofu skill](../opentofu/SKILL.md)).
The tailnet policy decides who reaches 5005; bastion's firewall admits it from any tailnet peer.
What bastion built for another host stays until its store runs low on space: bastion collects
garbage only then, not weekly ([builder.nix](../../../modules/builder.nix)).

```sh
nix run .#deploy -- HOST            # after checks pass on the committed revision
nix run .#deploy -- HOST --boot     # set the boot default only, no activation
nix run .#deploy -- servers         # bastion and edge; also workstations, or all
nix run .#reboot -- HOST            # reboot as deploy, e.g. after --boot
nix run .#shutdown -- HOST          # power off as deploy
nix run .#wake -- HOST              # bastion or beast by Wake-on-LAN, from home only (works from the Home VLAN, not over the tailnet); edge through the Oracle API
nix run .#unlock -- HOST            # send the disk passphrase to a host waiting in its initrd (hosts skill, edge.md)
```

The `deploy` app refuses a run that names no host or group, has uncommitted tracked changes, or passes
any flag outside its allow list, so none can skip the checks, turn a rollback off, stretch the confirm timeout or set SSH options; `clean` keeps the newest two generations, so
the previous one stays in the Limine menu. Each node carries a deploy-rs group, `servers` for an
`alwaysOn` host and `workstations` for the rest; a group deploys its online hosts in one run with
`--groups`, building concurrently and activating one after another, and a failure rolls back the
hosts already activated. "Online" comes from `tailscale status` on the deploying machine, the
coordination server's view, so a host switched off a minute ago may still count and fail the run.

Claude prepares the command and the operator runs it ([CLAUDE.md](../../../CLAUDE.md#autonomy)); a deploy
that changes SSH, firewall, Tailscale, users, sudo or this module is an access change. The first
activation of a host is a nixos-anywhere install, not a deploy. The installed generation has no
deploy-rs activation files, so the first deploy after an install cannot roll back to it: a failed
activation leaves the new configuration running with the profile pointing at the old generation,
until a deploy succeeds. Any failed unit fails the activation, so setup units stay idempotent and
do not fail on an outside service being down. A host without a tailnet
connection is unreachable to deploy-rs by design. No server accepts a console login or runs a getty, so recover
by booting the previous generation from the Limine menu on the provider or physical console, or
reinstall from the installer image as below.

## Install

[install.nix](../../../modules/install.nix) wraps nixos-anywhere for a host booted into an
installer image with its old disk mounted read-only: it copies the host's `fleet.carry` paths
(the SSH host key, `/var/lib/tailscale`, and what the host adds, such as bastion's Secure Boot
keys and ZFS key files) out of the old persist tree into an `--extra-files` tree, both under
`/persist` and at their live paths, since the installer reads some of them (Limine signs with
`/var/lib/sbctl`) before Preservation exists; on a `storage` host the root copy is gone on first boot, a `plain-storage` host gets only the live copy, and its reinstall mounts the old ext4 root and passes it as ROOT, not `/persist`. It then
unmounts the old disk, partitions with the host's disko layout and installs its configuration,
so the host keeps its SSH identity and its tailnet node, and sops-nix can decrypt on first boot.
A path that holds the only copy of a key goes in `fleet.carry` beside its owner, so no install
can forget it. Fleet hosts
admit no root login and no SSH off the tailnet ([ssh.nix](../../../modules/ssh.nix)), so a
reinstall always goes through the installer image, where root is the login. The disk is wiped;
it is an access change, and the operator runs it.

A new host has no old disk to carry from, and its facts need three values before its
configuration evaluates: the age recipient its secrets file is encrypted to, its tailnet address,
and the host key its initrd presents. The `enroll` app in install.nix makes that identity on the
operator's machine and prints the three: it generates the SSH host key and a separate initrd host
key, then logs a throwaway userspace `tailscaled` into the tailnet under the host's name with
the host's enrollment key ([tailnet.md](tailnet.md)), which spends the key, and stops
it. The directory it names holds the private halves laid out under `persist/`, so the node key
and host key never touch the provider's stock image. It sits beside the operator's sops key,
under `~/.config/sops`,
since it is the only copy until the host has booted. The install takes it as ROOT, stages it under `/persist` and at the live paths as for a reinstall, and leaves it
in place, since a finished install proves nothing about the first boot; the operator deletes it
once the host answers on the tailnet. Losing it before then means enrolling again and changing
the three facts.

```sh
nix run .#enroll -- HOST            # after the tailscale project minted HOST's enrollment key
ssh root@ADDRESS 'mkdir -p /mnt/old && mount -o ro /dev/DISK-PART /mnt/old'
nix run .#install -- HOST root@ADDRESS /mnt/old/persist
nix run .#install -- HOST USER@ADDRESS IDENTITY   # a new host, with the directory enroll named
```

An encrypted old disk is opened first, with `cryptsetup open /dev/DISK-PART old` and
`/dev/mapper/old` as the mounted device; disko closes the mapping before it wipes the disk, and
asks for the new passphrase on the terminal.

ADDRESS is the host's public or LAN address, not its MagicDNS name, since the tailnet node is replaced
during the install. The installer presents its own host key, so `ssh-keygen -R ADDRESS` first
and accept the new one; the carried key returns with the installed system. Rotate the host's auth key first ([tailnet.md](tailnet.md)) in
case the carried state is rejected; the key in the host file is only read when
`/var/lib/tailscale` holds no login.
