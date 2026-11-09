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

Tailscale is nix-darwin's `tailscaled`, which needs no app or system extension; the node
identity lives in its state directory and survives a switch. A re-enrolment uses the host's key from the
[OpenTofu project](../opentofu/SKILL.md), `tailscale up --auth-key file:PATH` with the key
written to a private file. sops-nix on darwin decrypts with the mac's SSH host key and holds the
GitHub MCP token and the build key for bastion ([secrets skill](../secrets/SKILL.md)). Touch ID answers sudo. Claude Code's
managed sandbox ([claude.nix](../../../modules/claude.nix)) admits no network host, so nothing a
sandboxed command reads can leave, and blocks writes to `.git/config`; git's network commands, `gh`
and creating a branch with an upstream run outside it. The old
generation's modules are reference only; a tool is added when the operator names it.

`flake.modules.darwin.desktop` is the laptop role: AeroSpace tiles with alt bindings, SketchyBar
replaces the menu bar and reads the Stylix palette, Vicinae is the launcher (its toggle shortcut
is set once in the app, `ctrl+comma`, since it owns `~/.config/vicinae/settings.json`),
`system.defaults` holds the macOS preferences. Vicinae is the one GUI app from nixpkgs, so its
launchd agent can point at the bundle. The other GUI apps are Homebrew casks from taps pinned
as flake inputs ([homebrew.nix](../../../modules/homebrew.nix)), so `brew tap` is refused and a
cask moves with `nix flake update homebrew-cask`; whatever the Brewfile stops naming is zapped at
activation, app data included, so preview a switch that drops a cask with
`brew bundle cleanup --file=<(nix eval --raw .#darwinConfigurations.mac.config.homebrew.brewfile)`. Claude Code ([claude.nix](../../../modules/claude.nix)) is the HM package with the
operator's settings; the sandbox and bypass lock live in the managed settings file that
activation installs under `/Library/Application Support/ClaudeCode`, which no user setting
overrides. The cache-tax mod is a flake input pinned to its release tag.
