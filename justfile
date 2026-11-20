default:
    @just --list

[doc("Format every file")]
fmt:
    nix fmt

[doc("Evaluate every host and every system's checks, building nothing")]
check:
    nix eval --raw .#nixosConfigurations.bastion.config.microvm.vms.hermes.config.config.services.hermes-agent.package.drvPath > /dev/null
    nix flake check --no-build --all-systems --option allow-import-from-derivation false

[arg("args", pattern='--?[a-z-]+')]
[arg("host", pattern='[a-z0-9-]+')]
[doc("Activate HOST's configuration from this checkout over the tailnet, with magic rollback; --boot sets the boot default only and has no rollback")]
deploy host *args:
    nix run .#deploy -- .#{{ host }} {{ args }}

[arg("hosts", pattern='[a-z0-9-]+')]
[doc("Deploy several HOSTS in one run: builds run concurrently, activations one after another, and a failed host rolls back the ones already activated")]
deploy-many +hosts:
    nix run .#deploy -- --targets {{ prepend('.#', hosts) }}

[arg("host", pattern='[a-z0-9-]+')]
[doc("Reboot HOST over the tailnet as the deploy account, e.g. after `just deploy HOST --boot`")]
reboot host:
    nix run .#reboot -- {{ host }}

[arg("host", pattern='[a-z0-9-]+')]
[doc("Power off HOST over the tailnet as the deploy account")]
shutdown host:
    nix run .#shutdown -- {{ host }}

[arg("host", pattern='[a-z0-9-]+')]
[doc("Power on bastion by Wake-on-LAN from a machine at home (it works from the Home VLAN, not over the tailnet), or edge through the Oracle Cloud API")]
wake host:
    nix run .#wake -- {{ host }}

[arg("host", pattern='[a-z0-9-]+')]
[doc("Send the disk passphrase to HOST waiting in its initrd, over SSH to its public address")]
unlock host:
    nix run .#unlock -- {{ host }}

[arg("host", pattern='[a-z0-9-]*')]
[doc("Delete every generation but the newest two, garbage-collect and optimise the store on HOST over the tailnet, or on this machine without HOST; on bastion this empties the build cache")]
clean host="":
    nix run .#clean -- {{ host }}

[doc("Switch the machine you are on to this checkout")]
switch:
    nh os switch .

[doc("Run OpenTofu in opentofu/PROJECT, e.g. `just tofu unifi plan`")]
[positional-arguments]
tofu project *args:
    nix run .#tofu -- "$@"

[doc("Compare (check) or merge (apply) the UniFi settings no provider writes")]
[positional-arguments]
unifi-settings action:
    nix run .#unifi-settings -- "$@"

[arg("host", pattern='[a-z0-9-]+')]
[doc("Make a new HOST's identity before its first install: SSH host keys and a tailnet login, in a private directory")]
enroll host:
    nix run .#enroll -- {{ host }}

[doc("Install HOST on TARGET with its identity: carried from the old persist tree ROOT on an installer, or for a new host from the directory ROOT that enroll made")]
[positional-arguments]
install host target root:
    nix run .#install -- "$@"

[doc("Update every flake input, NAME.pkg.nix pin, GitHub Action and OpenTofu provider")]
update:
    nix flake update
    nix run .#update-pins
