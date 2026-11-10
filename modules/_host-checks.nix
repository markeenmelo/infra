{ config, lib }:
name: enabled: check:
lib.foldlAttrs (
  acc: host: nixos:
  if !enabled nixos then
    acc
  else
    lib.recursiveUpdate acc {
      ${nixos.config.nixpkgs.hostPlatform.system}."${name}-${host}" = check host nixos;
    }
) { } config.flake.nixosConfigurations
