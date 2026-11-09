{ config, ... }:
let
  inherit (config.fleet) domain;
  hostname = "grafana.${domain}";
  admins = "grafana-admins";
  ports = {
    grafana = 3000;
    prometheus = 9090;
    loki = 3100;
    lokiGrpc = 9096;
    node = 9100;
  };
in
{
  flake.modules.nixos.monitoring =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      credentials = "/run/credentials/grafana.service";
      host = config.networking.hostName;
      # Node Exporter Full, grafana.com dashboard 1860
      nodeDashboard = pkgs.runCommand "node-exporter-full.json" { } ''
        sed 's/''${DS_PROMETHEUS}/prometheus/g' ${
          pkgs.fetchurl {
            url = "https://grafana.com/api/dashboards/1860/revisions/46/download";
            hash = "sha256-5Y3cXcU11MkB+U2pZIvD49Wue2946Y4YW86LKJlhzqM=";
          }
        } > $out
      '';
    in
    {
      sops.secrets =
        lib.genAttrs [ "grafana-oidc-client-secret" "grafana-secret-key" "grafana-admin-password" ]
          (name: {
            sopsFile = ../secrets/hosts/${host}.yaml;
            key = "grafana/${lib.removePrefix "grafana-" name}";
            restartUnits = [ "grafana.service" ];
          });
      systemd.services.grafana.serviceConfig.LoadCredential =
        map (name: "${lib.removePrefix "grafana-" name}:${config.sops.secrets.${name}.path}")
          [
            "grafana-oidc-client-secret"
            "grafana-secret-key"
            "grafana-admin-password"
          ];

      services = {
        prometheus = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = ports.prometheus;
          retentionTime = "30d";
          extraFlags = [ "--storage.tsdb.retention.size=20GB" ];
          globalConfig.scrape_interval = "60s";
          exporters.node = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = ports.node;
            enabledCollectors = [ "systemd" ];
          };
          scrapeConfigs =
            lib.mapAttrsToList
              (job: port: {
                job_name = job;
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString port}" ];
                    labels.instance = host;
                  }
                ];
              })
              {
                inherit (ports) node prometheus;
              };
        };

        loki = {
          enable = true;
          configuration = {
            auth_enabled = false;
            server = {
              http_listen_address = "127.0.0.1";
              http_listen_port = ports.loki;
              grpc_listen_address = "127.0.0.1";
              grpc_listen_port = ports.lokiGrpc;
            };
            common = {
              path_prefix = config.services.loki.dataDir;
              replication_factor = 1;
              ring = {
                instance_addr = "127.0.0.1";
                kvstore.store = "inmemory";
              };
              storage.filesystem = {
                chunks_directory = "${config.services.loki.dataDir}/chunks";
                rules_directory = "${config.services.loki.dataDir}/rules";
              };
            };
            schema_config.configs = [
              {
                from = "2026-11-01";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
            limits_config.retention_period = "720h";
            compactor = {
              working_directory = "${config.services.loki.dataDir}/compactor";
              retention_enabled = true;
              delete_request_store = "filesystem";
            };
            analytics.reporting_enabled = false;
          };
        };

        alloy.enable = true;

        grafana = {
          enable = true;
          settings = {
            server = {
              http_addr = "127.0.0.1";
              http_port = ports.grafana;
              domain = hostname;
              root_url = "https://${hostname}";
            };
            security = {
              secret_key = "$__file{${credentials}/secret-key}";
              admin_password = "$__file{${credentials}/admin-password}";
              cookie_secure = true;
              disable_gravatar = true;
            };
            users.allow_sign_up = false;
            analytics = {
              reporting_enabled = false;
              check_for_updates = false;
            };
            "auth.generic_oauth" = {
              enabled = true;
              name = "Authelia";
              client_id = "grafana";
              client_secret = "$__file{${credentials}/oidc-client-secret}";
              scopes = "openid profile email groups";
              auth_url = "https://auth.${domain}/api/oidc/authorization";
              token_url = "https://auth.${domain}/api/oidc/token";
              api_url = "https://auth.${domain}/api/oidc/userinfo";
              auth_style = "InHeader";
              use_pkce = true;
              login_attribute_path = "preferred_username";
              name_attribute_path = "name";
              groups_attribute_path = "groups";
              role_attribute_path = "contains(groups[*], '${admins}') && 'GrafanaAdmin' || ''";
              role_attribute_strict = true;
              allow_assign_grafana_admin = true;
              allow_sign_up = true;
            };
          };
          provision = {
            enable = true;
            datasources.settings.datasources = [
              {
                name = "Prometheus";
                uid = "prometheus";
                type = "prometheus";
                url = "http://127.0.0.1:${toString ports.prometheus}";
                isDefault = true;
                jsonData.timeInterval = "60s";
              }
              {
                name = "Loki";
                uid = "loki";
                type = "loki";
                url = "http://127.0.0.1:${toString ports.loki}";
              }
            ];
            dashboards.settings.providers = [
              {
                name = "fleet";
                allowUiUpdates = false;
                options.path = pkgs.linkFarm "dashboards" { "node-exporter-full.json" = nodeDashboard; };
              }
            ];
          };
        };
      };

      # 354 is the old generation's alloy uid
      users = {
        users = {
          alloy = {
            isSystemUser = true;
            uid = 354;
            group = "alloy";
            extraGroups = [ "systemd-journal" ];
          };
          loki.uid = 356;
        };
        groups = {
          alloy.gid = 354;
          loki.gid = 356;
        };
      };
      systemd.services.alloy.serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "alloy";
        Group = "alloy";
      };
      networking.nftables.enable = true;
      networking.nftables.tables.monitoring = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority -150; policy accept;
            oifname "lo" tcp dport { ${
              lib.concatMapStringsSep ", " toString (lib.attrValues (removeAttrs ports [ "grafana" ]))
            } } meta skuid != { 0, ${
              lib.concatMapStringsSep ", " (user: toString config.users.users.${user}.uid) [
                "grafana"
                "prometheus"
                "loki"
                "alloy"
              ]
            } } reject
          }
        '';
      };

      environment.etc."alloy/config.alloy".text = ''
        loki.relabel "journal" {
          forward_to = []
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
          rule {
            source_labels = ["__journal_syslog_identifier"]
            target_label  = "syslog_identifier"
          }
          rule {
            source_labels = ["__journal_priority_keyword"]
            target_label  = "level"
          }
        }

        loki.source.journal "journal" {
          max_age       = "12h"
          relabel_rules = loki.relabel.journal.rules
          labels        = { host = "${host}" }
          forward_to    = [loki.write.local.receiver]
        }

        loki.write "local" {
          endpoint {
            url = "http://127.0.0.1:${toString ports.loki}/loki/api/v1/push"
          }
        }
      '';

      fleet = {
        web.apps.grafana = {
          port = ports.grafana;
          tailnetOnly = true;
        };
        oidc.clients.grafana = {
          client_name = "Grafana";
          redirect_uris = [ "https://${hostname}/login/generic_oauth" ];
          scopes = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
        };
      };

      preservation.preserveAt."/persist".directories =
        lib.mapAttrsToList
          (directory: user: {
            inherit directory user;
            group = user;
            mode = "0700";
          })
          {
            "/var/lib/prometheus2" = "prometheus";
            ${config.services.loki.dataDir} = "loki";
            ${config.services.grafana.dataDir} = "grafana";
          };
    };
}
