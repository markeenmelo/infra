{ inputs, ... }:
{
  perSystem =
    {
      config,
      lib,
      pkgs,
      system,
      ...
    }:
    let
      pins = {
        caddy = [ "--version=skip" ];
        jellyfin-sso = [ ];
        noctalia-plugins = [ "--version=branch" ];
      };
      nix-update = inputs.nix-update.packages.${system}.nix-update;
      nixUpdate =
        name: flags:
        "GITHUB_TOKEN=\"$github_token\" "
        + lib.escapeShellArgs (
          [
            "nix-update"
            "--flake"
            "--override-filename"
            "modules/${name}.pkg.nix"
          ]
          ++ flags
          ++ [ "legacyPackages.${pkgs.stdenv.hostPlatform.system}.${name}" ]
        );
    in
    {
      legacyPackages = lib.mapAttrs (name: _: pkgs.callPackage ./${name}.pkg.nix { }) pins;
      packages.tack = inputs.tack.packages.${system}.tack;
      checks.tack-resolver = pkgs.runCommand "tack-resolver" { } ''
        cmp ${inputs.tack}/.tack/default.nix ${../.tack/default.nix} || {
          echo ".tack/default.nix differs from the resolver of the tack pin: run tack init --resolver" >&2
          exit 1
        }
        touch $out
      '';
      apps.update-pins = {
        meta.description = "update-pins: bump each NAME.pkg.nix in pins, every Caddy plugin, Grafana dashboard, the CrowdSec hub commit, tack's resolver, the GitHub Actions and the OpenTofu providers to the latest upstream, with their hashes";
        program = pkgs.writeShellApplication {
          name = "update-pins";
          excludeShellChecks = [ "SC2016" ];
          runtimeInputs = [
            pkgs.curl
            pkgs.git
            pkgs.gh
            pkgs.gnugrep
            pkgs.gnused
            pkgs.jaq
            pkgs.opentofu
            pkgs.pinact
            nix-update
            config.packages.tack
          ];
          text = lib.concatLines (
            [ (builtins.readFile ./update-pins.sh) ]
            ++ lib.mapAttrsToList nixUpdate pins
            ++ [ "update_providers" ]
          );
        };
      };
    };
}
