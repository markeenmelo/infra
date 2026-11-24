# Dorian

[dorian.nix](../../../modules/dorian.nix) runs the Discord slash-command bot
[Cthulu-Dice-Roller](https://github.com/markeenmelo/Cthulu-Dice-Roller) (`/croll`) as a
`DynamicUser` unit on bastion. The package is [dorian.pkg.nix](../../../modules/dorian.pkg.nix);
it fetches the private fork with `fetchFromGitHub { private = true; }` (the nix-daemon needs
`NIX_GITHUB_PRIVATE_USERNAME` and `NIX_GITHUB_PRIVATE_PASSWORD`) and builds py-cord from PyPI.
It is not in [pins.nix](../../../modules/pins.nix): nix-update cannot read a private atom feed or
prefetch through the daemon, so the rev is bumped by hand. Making the fork public lets it join
the pins and drops `private = true`.

## Secrets

`dorian/token` in `secrets/hosts/bastion.yaml` is the Discord bot token (`DORIAN_TOKEN`). The unit
reads it through `LoadCredential` and restarts when it changes.

```sh
sops set secrets/hosts/bastion.yaml '["dorian"]["token"]' "\"$DORIAN_TOKEN\""
```
