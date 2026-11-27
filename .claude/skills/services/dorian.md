# Dorian

[dorian.nix](../../../modules/dorian.nix) runs the Discord slash-command bot
[Cthulu-Dice-Roller](https://github.com/markeenmelo/Cthulu-Dice-Roller) (`/croll`) as a
`DynamicUser` unit on bastion. The package is [dorian.pkg.nix](../../../modules/dorian.pkg.nix),
built from the `dorian` tack pin, which `just update` moves to the repository's head; it builds
py-cord from PyPI.

## Secrets

`dorian/token` in `secrets/hosts/bastion.yaml` is the Discord bot token (`DORIAN_TOKEN`). The unit
reads it through `LoadCredential` and restarts when it changes.

```sh
sops set secrets/hosts/bastion.yaml '["dorian"]["token"]' "\"$DORIAN_TOKEN\""
```
