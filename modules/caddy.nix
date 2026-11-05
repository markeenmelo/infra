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
  flake.checks = lib.foldlAttrs (
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
        extraConfig = ''
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
