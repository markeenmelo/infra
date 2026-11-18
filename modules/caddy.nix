{ config, lib, ... }:
let
  identityHeaders = [
    "Remote-User"
    "Remote-Groups"
    "Remote-Email"
    "Remote-Name"
    "X-Forwarded-User"
    "X-Forwarded-Groups"
    "X-Forwarded-Email"
    "X-Forwarded-Preferred-Username"
    "X-Forwarded-Access-Token"
    "X-Real-IP"
    "Forwarded"
  ];
in
{
  options.fleet.domain = lib.mkOption {
    type = lib.types.str;
    description = "The domain every public and LAN hostname sits under.";
  };
  config.fleet.domain = "marcosmelo.dev";

  config.flake.modules.nixos.base =
    { lib, ... }:
    {
      options.fleet.web.apps = lib.mkOption {
        default = { };
        description = "Apps this host serves, by subdomain: the LAN proxy routes each to its address and port, and the public proxy does the same for the public ones, behind their denied paths.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              port = lib.mkOption { type = lib.types.port; };
              address = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1";
                description = "Address the proxies reach the app at, for apps confined to another network namespace.";
              };
              public = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the public proxy serves the app to the internet.";
              };
              denied = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Caddy matcher bodies the public proxy answers with 404, for admin paths that only the LAN and the tailnet reach.";
              };
            };
          }
        );
      };
      config.networking.nftables.enable = true;
    };

  config.flake.checks =
    import ./_host-checks.nix { inherit config lib; } "caddyfile"
      (nixos: nixos.config.services.caddy.enable)
      (
        name: nixos:
        let
          inherit (nixos.config.services) caddy;
        in
        nixos.pkgs.runCommand "caddyfile-${name}" { } ''
          sed "s|${caddy.logDir}|$TMPDIR|g" ${caddy.configFile} > Caddyfile
          HOME=$TMPDIR XDG_DATA_HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR \
            ${caddy.package}/bin/caddy validate --config Caddyfile --adapter caddyfile
          ${caddy.package}/bin/caddy adapt --config Caddyfile --adapter caddyfile > config.json
          ${lib.getExe nixos.pkgs.jq} -e --argjson expected '${builtins.toJSON identityHeaders}' '
            [ .apps.http.servers[].routes[]
              | [ .handle[]? | if .handler == "subroute"
                    then .routes[] | has("match") as $matched | .handle[] | { $matched, handler: . }
                    else { matched: false, handler: . } end ] as $steps
              | ($steps | to_entries | map(select(.value.handler | tojson | test("reverse_proxy"))) | map(.key) | min) as $proxy
              | select($proxy != null)
              | $expected - [ $steps[:$proxy][] | select(.matched | not) | .handler
                              | select(.handler == "headers") | .request.delete // [] | .[] ]
              | length == 0 ]
            | length > 0 and all' config.json > /dev/null
          touch $out
        ''
      );

  config.flake.modules.nixos.caddy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      key = "fleet-caddy";
      fleet.scrapeTargets.caddy = 19290;
      fleet.loopbackGuards.caddy-admin = {
        ports = [ 2019 ];
        users = [
          "root"
          config.services.caddy.user
        ];
      };
      sops = {
        secrets = lib.genAttrs [ "PORKBUN_API_KEY" "PORKBUN_SECRET_KEY" ] (_: { });
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
        package = pkgs.callPackage ./caddy.pkg.nix { };
        environmentFile = config.sops.templates.caddy-env.path;
        globalConfig = ''
          acme_ca https://acme-v02.api.letsencrypt.org/directory
          grace_period 10s
          metrics
        '';
        extraConfig = ''
          (porkbun) {
            tls {
              dns porkbun {
                api_key {env.PORKBUN_API_KEY}
                api_secret_key {env.PORKBUN_SECRET_KEY}
              }
              resolvers 1.1.1.1 9.9.9.9
            }
          }
          (identity) {
            ${lib.concatMapStrings (header: "request_header -${header}\n") identityHeaders}
          }
          :19290 {
            bind 127.0.0.1
            metrics
          }
        '';
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
