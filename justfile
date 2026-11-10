default:
    @just --list

[doc("Format every file")]
fmt:
    nix fmt

[doc("Evaluate every host and run the checks that need no build")]
check:
    nix flake check --no-build

[doc("Activate HOST's committed configuration over the tailnet, with magic rollback")]
deploy host:
    nix run .#deploy -- .#{{ host }}

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

[doc("Update every flake input")]
update:
    nix flake update
