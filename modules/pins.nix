{
  perSystem =
    { lib, pkgs, ... }:
    let
      pins = {
        cache-tax = [ "--version=branch" ];
        caddy = [ "--version=skip" ];
        caveman = [ "--version=branch" ];
        decluttarr = [ ];
        dorian = [ "--version=branch" ];
        claude-plugins-official = [ "--version=branch" ];
        trailofbits-skills = [ "--version=branch" ];
        easynews-indexer = [ "--version=branch" ];
        jellyfin-sso = [ ];
        noctalia-plugins = [ "--version=branch" ];
        ponytail = [ "--version=branch" ];
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
      apps.update-pins = {
        meta.description = "update-pins: bump every NAME.pkg.nix pin, every Caddy plugin, Grafana dashboard, the CrowdSec hub commit, the GitHub Actions and the OpenTofu providers to the latest upstream, with their hashes";
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
