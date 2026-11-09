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
    { config, lib, ... }:
    {
      options.fleet.web.apps = lib.mkOption {
        default = { };
        description = "Apps this host serves, by subdomain: the LAN proxy routes each to its address and port, and the edge forwards the public ones to the port over the tailnet with their denied paths.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              port = lib.mkOption { type = lib.types.port; };
              address = lib.mkOption {
                type = lib.types.str;
                default = "127.0.0.1";
                description = "Address the LAN proxy reaches the app at, for apps confined to another network namespace.";
              };
              tailnetOnly = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the LAN proxy refuses clients outside the tailnet.";
              };
              public = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether the edge publishes the app and the tailnet interface opens its port.";
              };
              denied = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Caddy matcher bodies the edge answers with 403, for admin paths that only the LAN and the tailnet reach.";
              };
            };
          }
        );
      };
      config.assertions = lib.mapAttrsToList (name: app: {
        assertion = app.public -> !app.tailnetOnly && app.address == "127.0.0.1";
        message = "fleet.web.apps.${name}: the edge reaches a public app on the host's port, bypassing the LAN proxy, so it cannot be tailnetOnly or live at another address.";
      }) config.fleet.web.apps;
      config.networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        lib.mapAttrsToList (_: app: app.port)
          (lib.filterAttrs (_: app: app.public) config.fleet.web.apps);
    };

  config.flake.checks = lib.foldlAttrs (
    acc: name: host:
    let
      nixos = config.flake.nixosConfigurations.${name};
      inherit (nixos.config.services) caddy;
    in
    if lib.hasSuffix "-darwin" host.system || !caddy.enable then
      acc
    else
      lib.recursiveUpdate acc {
        ${host.system}."caddyfile-${name}" = nixos.pkgs.runCommand "caddyfile-${name}" { } ''
          sed "s|${caddy.logDir}|$TMPDIR|g" ${caddy.configFile} > Caddyfile
          HOME=$TMPDIR XDG_DATA_HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR \
            ${caddy.package}/bin/caddy validate --config Caddyfile --adapter caddyfile
          ${caddy.package}/bin/caddy adapt --config Caddyfile --adapter caddyfile > config.json
          ${lib.getExe nixos.pkgs.jq} -e --argjson expected '${builtins.toJSON identityHeaders}' '
            [ .apps.http.servers[].routes[] | .handle[]? | select(.handler == "subroute") | .routes[] ] as $site
            | ($site | to_entries | map(select(.value | tojson | test("reverse_proxy"))) | map(.key) | min // ($site | length)) as $proxy
            | $expected - [ $site[:$proxy][] | select(has("match") | not) | .handle[]
                            | select(.handler == "headers") | .request.delete // [] | .[] ]
              | length == 0' config.json > /dev/null
          touch $out
        '';
      }
  ) { } config.fleet.hosts;

  config.flake.modules.nixos.caddy =
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
          hash = "sha256-oIhRCKOI8zD5BTIZcoZgEi/wfj7BTvm+Hqpu/LwrLPA=";
        };
        environmentFile = config.sops.templates.caddy-env.path;
        globalConfig = "grace_period 10s";
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
