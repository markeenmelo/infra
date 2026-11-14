default:
    @just --list

[doc("Format every file")]
fmt:
    nix fmt

[doc("Evaluate every host and every system's checks, building nothing")]
check:
    nix flake check --no-build --all-systems

[doc("Activate HOST's configuration from this checkout over the tailnet, with magic rollback; extra flags such as --boot pass to deploy-rs")]
deploy host *args:
    nix run .#deploy -- .#{{ host }} {{ args }}

[doc("Deploy several HOSTS in one run: builds run concurrently, activations one after another, and a failed host rolls back the ones already activated")]
deploy-many +hosts:
    nix run .#deploy -- --targets {{ prepend('.#', hosts) }}

[doc("Reboot HOST over the tailnet as the deploy account, e.g. after `just deploy HOST --boot`")]
reboot host:
    nix run .#reboot -- {{ host }}

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

[doc("Update every flake input and every NAME.pkg.nix pin")]
update:
    nix flake update
    nix run .#update-pins
