{
  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.crowdsec;
      yaml = pkgs.formats.yaml { };
    in
    {
      config = lib.mkIf cfg.enable {
        services.crowdsec = {
          openFirewall = false;
          autoUpdateService = false;
          hub = {
            branch = "4c9fec5fe135c0b23d0059ae3e4ea9a6936e2f48";
            collections = [
              "crowdsecurity/sshd"
              "crowdsecurity/traefik"
              "crowdsecurity/appsec-virtual-patching"
              "crowdsecurity/appsec-generic-rules"
            ];
            parsers = [
              "crowdsecurity/syslog-logs"
              "crowdsecurity/dateparse-enrich"
              "crowdsecurity/geoip-enrich"
            ];
          };
          settings = {
            lapi.credentialsFile = "/var/lib/crowdsec/local_api_credentials.yaml";
            general = {
              api.server = {
                enable = true;
                listen_uri = "127.0.0.1:8080";
                online_client = lib.mkForce null;
              };
              prometheus.enabled = false;
              cscli.__hub_url_template__ = "https://raw.githubusercontent.com/crowdsecurity/hub/%s/%s";
            };
          };
          localConfig.acquisitions = [
            {
              source = "journalctl";
              journalctl_filter = [
                "_SYSTEMD_UNIT=sshd.service"
                "--output=short"
                "--utc"
              ];
              labels.type = "syslog";
            }
            {
              source = "journalctl";
              journalctl_filter = [
                "_SYSTEMD_UNIT=traefik.service"
                "--output=cat"
              ];
              labels.type = "traefik";
            }
            {
              source = "appsec";
              listen_addr = "127.0.0.1:7422";
              appsec_config_path = "${../assets/crowdsec/appsec.yaml}";
              labels.type = "appsec";
            }
          ];
          localConfig.profiles = lib.mkForce [
            {
              name = "local_ip_bans";
              filters = [ "Alert.Remediation == true && Alert.GetScope() == 'Ip'" ];
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
        assertions = [
          {
            assertion =
              cfg.settings.capi.credentialsFile == null
              && cfg.settings.console.tokenFile == null
              && cfg.settings.general.api.server.online_client == null;
            message = "Local CrowdSec must not implicitly enroll or share signals with CAPI/Console.";
          }
          {
            assertion =
              !(builtins.elem "crowdsecurity/linux" cfg.hub.collections)
              && cfg.localConfig.postOverflows.s01Whitelist == [ ];
            message = "Review CrowdSec dependency closure: no linux collection, crawler or blanket private-client whitelist.";
          }
        ];
        environment.etc = {
          "crowdsec/config.yaml".source = yaml.generate "crowdsec.yaml" cfg.settings.general;
          "crowdsec/appsec-rules/fleet-bots.yaml".source = ../assets/crowdsec/bots.yaml;
        };
        systemd.services = {
          crowdsec = {
            path = lib.mkForce [ pkgs.systemd ];
            serviceConfig = {
              DynamicUser = lib.mkForce false;
              StateDirectory = "crowdsec";
              StateDirectoryMode = "0700";
            };
          };
          crowdsec-firewall-bouncer.after = [ "crowdsec-firewall-bouncer-register.service" ];
          crowdsec-firewall-bouncer-register.serviceConfig = {
            DynamicUser = lib.mkForce false;
            StateDirectoryMode = "0700";
          };
        };
        environment.persistence."/persist".directories =
          map
            (directory: {
              inherit directory;
              user = cfg.user;
              group = cfg.group;
              mode = "0700";
            })
            [
              "/var/lib/crowdsec"
              "/var/lib/crowdsec-firewall-bouncer-register"
            ];
        services.crowdsec-firewall-bouncer = {
          enable = true;
          createRulesets = false;
          registerBouncer.enable = true;
          settings = {
            mode = "nftables";
            update_frequency = "5s";
            disable_ipv6 = false;
            nftables.ipv4 = {
              enabled = true;
              set-only = true;
              table = "crowdsec";
              chain = "input";
            };
            nftables.ipv6 = {
              enabled = true;
              set-only = true;
              table = "crowdsec6";
              chain = "input";
            };
          };
        };
        networking.nftables.tables = {
          crowdsec = {
            family = "ip";
            content = ''
              set crowdsec-blacklists { type ipv4_addr; flags timeout; }
              chain input {
                type filter hook input priority -10; policy accept;
                ip saddr @crowdsec-blacklists tcp dport { 22, 443 } drop
              }
            '';
          };
          crowdsec6 = {
            family = "ip6";
            content = ''
              set crowdsec6-blacklists { type ipv6_addr; flags timeout; }
              chain input {
                type filter hook input priority -10; policy accept;
                ip6 saddr @crowdsec6-blacklists tcp dport { 22, 443 } drop
              }
            '';
          };
        };
      };
    };
  fleet.hosts.racknerd.module = { config, lib, ... }: {
    environment.etc."crowdsec/scenarios/fleet-public-non-canada.yaml" =
      lib.mkIf config.services.crowdsec.enable
        { source = ../assets/crowdsec/public-non-canada.yaml; };
  };
}
