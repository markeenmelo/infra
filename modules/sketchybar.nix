{ config, ... }:
let
  inherit (config.fleet) domain;
in
{
  flake.modules.darwin.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      workspaces = map (lib.removePrefix "workspace ") (
        lib.filter (lib.hasPrefix "workspace ") (
          lib.attrValues config.services.aerospace.settings.mode.main.binding
        )
      );
      rc = pkgs.replaceVars ./sketchybar.lua {
        inherit (config.lib.stylix.colors)
          base00
          base01
          base02
          base03
          base05
          base08
          base0A
          base0D
          ;
        font = config.stylix.fonts.monospace.name;
        workspaces = lib.concatMapStringsSep ", " (n: ''"${n}"'') workspaces;
        icalbuddy = "${config.homebrew.prefix}/bin/icalBuddy";
        grafana = "https://grafana.${domain}";
        grafanaToken = config.sops.secrets.grafana-mcp-token.path;
      };
    in
    {
      system.defaults.NSGlobalDomain._HIHideMenuBar = true;
      homebrew.brews = [ "ical-buddy" ];
      home-manager.users.${config.system.primaryUser}.programs.sketchybar = {
        enable = true;
        configType = "lua";
        extraPackages = [ config.services.aerospace.package ];
        config.text = ''dofile("${rc}")'';
      };
    };
}
