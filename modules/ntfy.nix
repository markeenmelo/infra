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
}
