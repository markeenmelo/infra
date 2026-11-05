{
  flake.modules.nixos.caddy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      sops = {
        secrets = lib.genAttrs [ "PORKBUN_API_KEY" "PORKBUN_SECRET_KEY" ] (key: {
          sopsFile = ../secrets/porkbun/api.yaml;
        });
        templates.caddy-env = {
          content = ''
            PORKBUN_API_KEY=${config.sops.placeholder.PORKBUN_API_KEY}
            PORKBUN_SECRET_KEY=${config.sops.placeholder.PORKBUN_SECRET_KEY}
          '';
          restartUnits = [ "caddy.service" ];
        };
      };
      services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = [
            "github.com/caddy-dns/porkbun@v0.3.1"
            "github.com/porech/caddy-maxmind-geolocation@v1.0.3"
          ];
          hash = "sha256-urSgwaKHIncei86b1G8SM3iViwTei98aX+XysbZ/2UE=";
        };
        environmentFile = config.sops.templates.caddy-env.path;
        globalConfig = "grace_period 10s";
      };
      systemd.services.caddy.serviceConfig.StateDirectoryMode = "0700";
      preservation.preserveAt."/persist".directories = [
        {
          directory = config.services.caddy.dataDir;
          user = config.services.caddy.user;
          group = config.services.caddy.group;
          mode = "0700";
        }
      ];
    };
}
