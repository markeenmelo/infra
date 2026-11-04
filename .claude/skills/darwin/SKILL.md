---
name: darwin
description: "The mac host: nix-darwin plus Home Manager built from the same dendritic modules as NixOS, how it is switched, what the darwin base sets, what deploy-rs and sops do not cover on it. Use before touching modules/hosts/mac, any flake.modules.darwin or flake.modules.homeManager value, or switching the mac."
---

# mac

A concern that applies to macOS sets `flake.modules.darwin.base` in the same file as its NixOS
counterpart; [fleet.nix](../../../modules/fleet.nix) turns a host with `darwin` set into
`darwinConfigurations.NAME` and the `darwin-NAME` check, which the mac builds for itself and
the macOS runner builds in CI. Home Manager runs as a nix-darwin module
([home.nix](../../../modules/home.nix)); operator settings portable across hosts go to
`flake.modules.homeManager.base`.

The mac switches itself; deploy-rs manages NixOS hosts only:

```sh
sudo darwin-rebuild switch --flake .#mac
```

Tailscale is nix-darwin's `tailscaled`, joined by hand with `tailscale up` once; there is no
auth key secret because sops-nix is not wired on darwin. Touch ID answers sudo. The old
generation's window manager, bar, launcher, theme and editor modules are reference only: the
rewrite keeps macOS defaults and adds a tool when the operator names it.
