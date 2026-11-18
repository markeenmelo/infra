{ config, lib, ... }:
let
  inherit (config.fleet) hosts;
  bastion = hosts.bastion.tailnetAddress;
  edge = hosts.edge.tailnetAddress;
  port = config.fleet.bansPort;
  engine =
    { config, lib, ... }:
    let
      cfg = config.services.crowdsec;
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
            api.server.online_client.credentials_path = "/var/lib/crowdsec/online_api_credentials.yaml";
            cscli = {
              hub_branch = "6c21c2716fc1780e06e10dacdba9a8a5055263eb";
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
      systemd.services = {
        crowdsec = {
          after = [ "caddy.service" ];
          restartTriggers = [
            (lib.toJSON cfg.settings)
            (lib.toJSON cfg.hub)
          ];
          serviceConfig = {
            DynamicUser = lib.mkForce false;
            StateDirectory = "crowdsec";
            StateDirectoryMode = "0700";
          };
        };
        crowdsec-setup.serviceConfig.DynamicUser = lib.mkForce false;
      };
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

  config.flake.modules.nixos.crowdsec =
    { config, ... }:
    {
      imports = [ engine ];
      services.crowdsec-firewall-bouncer.enable = true;
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/crowdsec-firewall-bouncer-register";
          inherit (config.services.crowdsec) user group;
          mode = "0750";
        }
      ];
    };

  config.flake.modules.nixos.crowdsec-engine =
    { config, ... }:
    {
      imports = [ engine ];
      services.crowdsec.settings.config.api.server.listen_uri = "0.0.0.0:${toString port}";
      sops.secrets."crowdsec/edge-bouncer-key".restartUnits = [ "crowdsec-edge-bouncer.service" ];
      systemd.services.crowdsec-edge-bouncer = {
        description = "Register the edge's firewall bouncer with CrowdSec";
        wantedBy = [ "multi-user.target" ];
        after = [ "crowdsec.service" ];
        wants = [ "crowdsec.service" ];
        path = [ config.services.crowdsec.package ];
        enableStrictShellChecks = true;
        script = ''
          cscli bouncers delete edge > /dev/null 2>&1 || true
          cscli bouncers add edge --key "$(< "$CREDENTIALS_DIRECTORY/key")" > /dev/null
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = config.services.crowdsec.user;
          Group = config.services.crowdsec.group;
          LoadCredential = "key:${config.sops.secrets."crowdsec/edge-bouncer-key".path}";
        };
      };
      networking.firewall.extraInputRules = ''
        iifname "${config.services.tailscale.interfaceName}" ip saddr ${edge} tcp dport ${toString port} accept
      '';
    };

  config.flake.modules.nixos.crowdsec-bouncer =
    { config, ... }:
    {
      sops.secrets.crowdsec-bouncer-key.restartUnits = [ "crowdsec-firewall-bouncer.service" ];
      services.crowdsec-firewall-bouncer = {
        enable = true;
        secrets.apiKeyPath = config.sops.secrets.crowdsec-bouncer-key.path;
        settings.api_url = "http://${bastion}:${toString port}/";
      };
    };
}
