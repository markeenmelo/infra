{
  perSystem =
    { lib, pkgs, ... }:
    let
      pins = {
        caddy = [ "--version=skip" ];
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
        meta.description = "update-pins: bump every NAME.pkg.nix pin, Caddy plugin, Grafana dashboard and the CrowdSec hub commit to the latest upstream, with their hashes";
        program = pkgs.writeShellApplication {
          name = "update-pins";
          runtimeInputs = [
            pkgs.curl
            pkgs.git
            pkgs.gnused
            pkgs.jq
            pkgs.nix-update
          ];
          text = lib.concatLines (
            [ (builtins.readFile ./update-pins.sh) ]
            ++ lib.mapAttrsToList (
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
