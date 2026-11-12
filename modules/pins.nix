{
  perSystem =
    { lib, pkgs, ... }:
    let
      pins = {
        cache-tax = [ "--version=branch" ];
        caveman = [ "--version=branch" ];
        decluttarr = [ ];
        easynews-indexer = [ "--version=branch" ];
        jellyfin-sso = [ ];
        ponytail = [ "--version=branch" ];
        vicinae-coffee = [ "--version=branch" ];
      };
    in
    {
      legacyPackages = lib.mapAttrs (name: _: pkgs.callPackage ./${name}.pkg.nix { }) pins;
      apps.update-pins = {
        meta.description = "update-pins: bump every NAME.pkg.nix pin and its hashes to the latest upstream release or commit";
        program = pkgs.writeShellApplication {
          name = "update-pins";
          runtimeInputs = [ pkgs.nix-update ];
          text = lib.concatLines (
            lib.mapAttrsToList (
              name: flags:
              lib.escapeShellArgs (
                [
                  "nix-update"
                  "--flake"
                  "--override-filename"
                  "modules/${name}.pkg.nix"
                ]
                ++ flags
                ++ [ "legacyPackages.${pkgs.stdenv.hostPlatform.system}.${name}" ]
              )
            ) pins
          );
        };
      };
    };
}
