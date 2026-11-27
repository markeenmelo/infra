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
      # shortcut: nix 2.35 no longer copies the flake on `nix flake metadata`, the store path nix-update evaluates; drop the override once nix-update copies it itself
      nix-update = pkgs.nix-update.override { nix = pkgs.nixVersions.nix_2_34; };
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
        meta.description = "update-pins: bump every NAME.pkg.nix pin, every Caddy plugin, Grafana dashboard, the CrowdSec hub commit, tack's resolver, the GitHub Actions and the OpenTofu providers to the latest upstream, with their hashes";
        program = pkgs.writeShellApplication {
          name = "update-pins";
          runtimeInputs = [
            pkgs.curl
            pkgs.git
            pkgs.gh
            pkgs.gnugrep
            pkgs.gnused
            pkgs.jq
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
