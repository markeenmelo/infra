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

[doc("Switch the mac")]
mac:
    sudo darwin-rebuild switch --flake .#mac

[doc("Run OpenTofu in opentofu/PROJECT, e.g. `just tofu unifi plan`")]
tofu project *args:
    nix run .#tofu -- {{ project }} {{ args }}

[doc("Compare (check) or merge (apply) the UniFi settings no provider writes")]
unifi-settings action:
    nix run .#unifi-settings -- {{ action }}

[doc("Reinstall HOST from an installer at TARGET, carrying its identity from the old persist tree ROOT")]
install host target root:
    nix run .#install -- {{ host }} {{ target }} {{ root }}

[doc("Update every flake input")]
update:
    nix flake update
