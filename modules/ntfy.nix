{ config, ... }:
let
  inherit (config.fleet) domain;
  port = 2586;
in
{
  flake.modules.nixos.ntfy =
    { config, ... }:
    let
      topics = [
        "alerts"
        "media"
      ];
      secret = name: { key = "ntfy/${name}"; };
    in
    {
      sops = {
        secrets = {
          ntfy-publisher-hash = secret "publisher-hash";
          ntfy-publisher-token = secret "publisher-token";
        };
        templates."ntfy.env" = {
          content = ''
            NTFY_AUTH_USERS='publisher:${config.sops.placeholder.ntfy-publisher-hash}:user'
            NTFY_AUTH_TOKENS='publisher:${config.sops.placeholder.ntfy-publisher-token}'
          '';
          restartUnits = [ "ntfy-sh.service" ];
        };
      };
      # shortcut: the message cache lives in the rolled-back root, so a phone offline across a bastion reboot misses alerts sent just before it; preserve /var/lib/private/ntfy-sh if that matters
      services.ntfy-sh = {
        enable = true;
        settings = {
          base-url = "https://ntfy.${domain}";
          listen-http = "127.0.0.1:${toString port}";
          behind-proxy = true;
          auth-default-access = "deny-all";
          auth-access = map (topic: "*:${topic}:ro") topics ++ [ "publisher:*:wo" ];
        };
        environmentFile = config.sops.templates."ntfy.env".path;
      };
      fleet.web.apps.ntfy = { inherit port; };
    };

  flake.modules.darwin.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      notify = pkgs.writeShellScript "ntfy-notify" ''
        exec /usr/bin/osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv)' -e 'end run' "''${NTFY_TITLE:-alerts}" "$NTFY_MESSAGE"
      '';
    in
    {
      home-manager.users.${config.system.primaryUser}.launchd.agents.ntfy-alerts = {
        enable = true;
        config = {
          ProgramArguments = [
            (lib.getExe' pkgs.ntfy-sh "ntfy")
            "subscribe"
            "ntfy.${domain}/alerts"
            "${notify}"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 30;
        };
      };
    };

  flake.modules.homeManager.desktop =
    { lib, pkgs, ... }:
    let
      notify = pkgs.writeShellScript "ntfy-notify" ''
        urgency=normal
        if [ "''${NTFY_PRIORITY:-3}" -ge 4 ]; then urgency=critical; fi
        exec ${lib.getExe' pkgs.libnotify "notify-send"} --app-name=ntfy --urgency="$urgency" "''${NTFY_TITLE:-alerts}" "$NTFY_MESSAGE"
      '';
    in
    {
      systemd.user.services.ntfy-alerts = {
        Unit = {
          Description = "Show the fleet's alerts as desktop notifications";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${lib.getExe' pkgs.ntfy-sh "ntfy"} subscribe ntfy.${domain}/alerts ${notify}";
          Restart = "always";
          RestartSec = 30;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
}
