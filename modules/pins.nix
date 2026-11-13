{
  perSystem =
    { lib, pkgs, ... }:
    let
      pins = {
        caddy = [ "--version=skip" ];
        decluttarr = [ ];
        easynews-indexer = [ "--version=branch" ];
        jellyfin-sso = [ ];
        vicinae-coffee = [ "--version=branch" ];
      };
      # shortcut: nix 2.35 no longer copies the flake on `nix flake metadata`, the store path nix-update evaluates; drop the override once nix-update copies it itself
      nix-update = pkgs.nix-update.override { nix = pkgs.nixVersions.nix_2_34; };
      plugins = lib.genAttrs [ "cache-tax" "caveman" "noctalia-plugins" "ponytail" ] (_: [
        "--version=branch"
      ]);
      nixUpdate =
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
        );
    in
    {
      legacyPackages = lib.mapAttrs (name: _: pkgs.callPackage ./${name}.pkg.nix { }) (
        lib.mergeAttrsList [
          pins
          plugins
        ]
      );
      apps.update-pins = {
        meta.description = "update-pins: bump every NAME.pkg.nix pin except the plugins, every Caddy plugin, Grafana dashboard and the CrowdSec hub commit to the latest upstream, with their hashes";
        program = pkgs.writeShellApplication {
          name = "update-pins";
          runtimeInputs = [
            pkgs.curl
            pkgs.git
            pkgs.gnused
            pkgs.jq
            nix-update
          ];
          text = lib.concatLines (
            [ (builtins.readFile ./update-pins.sh) ] ++ lib.mapAttrsToList nixUpdate pins
          );
        };
      };
      apps.update-plugin = {
        meta.description = "update-plugin NAME: bump one Claude Code or Noctalia plugin pin (${lib.concatStringsSep ", " (lib.attrNames plugins)}) to its default branch";
        program = pkgs.writeShellApplication {
          name = "update-plugin";
          runtimeInputs = [ nix-update ];
          text = ''
            case ''${1-} in
            ${
              lib.concatStrings (
                lib.mapAttrsToList (name: flags: "${name}) ${nixUpdate name flags} ;;\n") plugins
              )
            }*) echo "usage: update-plugin ${lib.concatStringsSep "|" (lib.attrNames plugins)}" >&2; exit 1 ;;
            esac
          '';
        };
      };
    };
}
