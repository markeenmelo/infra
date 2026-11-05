{
  flake.modules.nixos.crowdsec =
    { config, lib, ... }:
    let
      cfg = config.services.crowdsec;
    in
    {
      networking.nftables.enable = true;
      services.crowdsec = {
        enable = true;
        extraGroups = [ config.services.caddy.group ];
        readOnlyPaths = [ config.services.caddy.logDir ];
        hub.collections = [ "crowdsecurity/caddy" ];
        settings = {
          config = {
            db_config.use_wal = true;
            api.server.online_client.credentials_path = "/var/lib/crowdsec/online_api_credentials.yaml";
            cscli = {
              hub_branch = "a7d441606d89f736911841c0b48151f334a2e0ce";
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
              description = "Repeated denials by the edge itself: abroad or an admin path";
              filter = "evt.Meta.log_type == 'http_access-log' && evt.Meta.http_status == '403' && evt.Line.Raw contains 'Edge-Denied'";
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
      services.crowdsec-firewall-bouncer.enable = true;
      systemd.services = {
        crowdsec = {
          after = [ "caddy.service" ];
          restartTriggers = [ (lib.toJSON cfg.settings) ];
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
        {
          directory = "/var/lib/crowdsec-firewall-bouncer-register";
          inherit (cfg) user group;
          mode = "0750";
        }
      ];
    };
}
