{ config, lib, ... }:
let
  inherit (config.fleet) hosts;
  bastion = hosts.bastion.tailnetAddress;
  edge = hosts.edge.tailnetAddress;
  port = config.fleet.bansPort;
  engine =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.crowdsec;
      state = {
        DynamicUser = lib.mkForce false;
        StateDirectory = map (lib.removePrefix "/var/lib/") [
          "/var/lib/crowdsec"
          cfg.settings.config.config_paths.data_dir
          cfg.settings.config.config_paths.hub_dir
        ];
        StateDirectoryMode = "0700";
      };
    in
    {
      services.crowdsec = {
        enable = true;
        extraGroups = [ config.services.caddy.group ];
        readOnlyPaths = [ config.services.caddy.logDir ];
        hub = {
          collections = [ "crowdsecurity/caddy" ];
          parsers = [
            "crowdsecurity/syslog-logs"
            "crowdsecurity/dateparse-enrich"
            "crowdsecurity/geoip-enrich"
          ];
        };
        settings = {
          config = {
            db_config.use_wal = true;
            prometheus = {
              enabled = true;
              level = "full";
              listen_addr = "127.0.0.1";
              listen_port = 6060;
            };
            api.server = {
              listen_uri = "0.0.0.0:${toString port}";
              online_client.credentials_path = "/var/lib/crowdsec/online_api_credentials.yaml";
            };
            cscli = {
              hub_branch = "bbaa9ed14e01065f146aa592cb19df6bc99bc263";
              __hub_url_template__ = "https://raw.githubusercontent.com/crowdsecurity/hub/%s/%s";
            };
          };
          acquisitions = [
            {
              source = "file";
              filenames = [ "${config.services.caddy.logDir}/access.log" ];
              labels.type = "caddy";
            }
          ];
          scenarios = [
            {
              name = "fleet/edge-denied";
              description = "Repeated denials by the edge itself: abroad, a crawler or an admin path";
              filter = "evt.Meta.log_type == 'http_access-log' && evt.Line.Raw contains '\"edge_denied\":'";
              type = "leaky";
              groupby = "evt.Meta.source_ip";
              capacity = 5;
              leakspeed = "1m";
              blackhole = "5m";
              labels = {
                service = "http";
                type = "policy";
                remediation = true;
                confidence = 3;
                spoofable = 0;
                label = "Edge denied";
              };
            }
          ];
          profiles = [
            {
              name = "escalating_ip_ban";
              filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Ip'" ];
              duration_expr = "Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)";
              decisions = [
                {
                  type = "ban";
                  duration = "4h";
                }
              ];
              on_success = "break";
            }
          ];
        };
      };
      fleet.scrapeTargets.crowdsec = cfg.settings.config.prometheus.listen_port;
      sops.secrets."crowdsec/edge-bouncer-key".restartUnits = [ "crowdsec-edge-bouncer.service" ];
      systemd.services = {
        crowdsec = {
          after = [ "caddy.service" ];
          restartTriggers = [
            (lib.toJSON cfg.settings)
            (lib.toJSON cfg.hub)
          ];
          serviceConfig = state;
        };
        crowdsec-setup.serviceConfig = state;
        crowdsec-edge-bouncer = {
          description = "Register the edge's firewall bouncer with CrowdSec";
          wantedBy = [ "multi-user.target" ];
          after = [ "crowdsec.service" ];
          wants = [ "crowdsec.service" ];
          path = [
            cfg.package
            pkgs.curl
          ];
          enableStrictShellChecks = true;
          script = ''
            key=$CREDENTIALS_DIRECTORY/key
            if curl -fsS -o /dev/null --retry 15 --retry-connrefused --retry-delay 2 \
              -H @<(printf 'X-Api-Key: %s\n' "$(< "$key")") 'http://127.0.0.1:${toString port}/v1/decisions?ip=192.0.2.1'; then
              exit 0
            fi
            cscli bouncers delete edge > /dev/null 2>&1 || true
            # shortcut: cscli takes the key on argv only, so a local process can read it from /proc while this runs; feed it from a file once cscli can
            cscli bouncers add edge --key "$(< "$key")" > /dev/null
          '';
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = cfg.user;
            Group = cfg.group;
            LoadCredential = "key:${config.sops.secrets."crowdsec/edge-bouncer-key".path}";
          };
        };
      };
      networking.firewall.extraInputRules = ''
        iifname "${config.services.tailscale.interfaceName}" ip saddr ${edge} tcp dport ${toString port} accept
      '';
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/crowdsec";
          inherit (cfg) user group;
          mode = "0700";
        }
      ];
    };
in
{
  options.fleet.bansPort = lib.mkOption {
    type = lib.types.port;
    description = "Port on bastion's tailnet address where CrowdSec's local API serves ban decisions to the edge's firewall bouncer; the `tofu` app hands it to `opentofu/tailscale` as `fleet_bans_port`.";
  };
  config.fleet.bansPort = 8081;

  config.flake.modules.nixos.crowdsec-engine = engine;

  config.flake.modules.nixos.crowdsec-bouncer =
    { config, ... }:
    {
      sops.secrets.crowdsec-bouncer-key.restartUnits = [ "crowdsec-firewall-bouncer.service" ];
      services.crowdsec-firewall-bouncer = {
        enable = true;
        secrets.apiKeyPath = config.sops.secrets.crowdsec-bouncer-key.path;
        settings = {
          api_url = "http://${bastion}:${toString port}/";
          retry_initial_connect = true;
        };
      };
      systemd.services.crowdsec-firewall-bouncer.serviceConfig = {
        Restart = "on-failure";
        RestartSec = 30;
      };
    };
}
