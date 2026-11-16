default:
    @just --list

[doc("Format every file")]
fmt:
    nix fmt

[doc("Evaluate every host and every system's checks, building nothing")]
check:
    nix flake check --no-build --all-systems

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
[doc("Power on bastion by Wake-on-LAN from a machine at home (it works from the Home VLAN, not over the tailnet), or racknerd through the RackNerd API")]
wake host:
    nix run .#wake -- {{ host }}

[arg("host", pattern='[a-z0-9-]*')]
[doc("Delete every generation but the newest two, garbage-collect and optimise the store on HOST over the tailnet, or on this machine without HOST; on bastion this empties the build cache")]
clean host="":
    nix run .#clean -- {{ host }}

[doc("Switch the machine you are on to this checkout: the mac, the thinkpad or asahi")]
switch:
    nh {{ if os() == "macos" { "darwin" } else { "os" } }} switch .

[doc("Run OpenTofu in opentofu/PROJECT, e.g. `just tofu unifi plan`")]
[positional-arguments]
tofu project *args:
    nix run .#tofu -- "$@"

[doc("Compare (check) or merge (apply) the UniFi settings no provider writes")]
[positional-arguments]
unifi-settings action:
    nix run .#unifi-settings -- "$@"

[doc("Reinstall HOST from an installer at TARGET, carrying its identity from the old persist tree ROOT")]
[positional-arguments]
install host target root:
    nix run .#install -- "$@"

[doc("Update every flake input, NAME.pkg.nix pin, GitHub Action and OpenTofu provider")]
update:
    nix flake update
    nix run .#update-pins
