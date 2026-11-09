{ config, lib, ... }:
let
  inherit (config.fleet) domain hosts;
  bastion = hosts.bastion.tailnetAddress;
  senders = lib.filterAttrs (_: host: host.telemetry != null) hosts;
  journal = forward: labels: ''
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
      labels        = ${labels}
      forward_to    = [${forward}]
    }
  '';
  inherit (config.flake.modules.nixos) ntfy;
  hostname = "grafana.${domain}";
  admins = "grafana-admins";
  ports = {
    grafana = 3000;
    prometheus = 9090;
    loki = 3100;
    lokiGrpc = 9096;
    node = 19100;
  };
in
{
  flake.modules.nixos.base =
    { lib, ... }:
    {
      options.fleet = {
        scrapeTargets = lib.mkOption {
          type = lib.types.attrsOf lib.types.port;
          default = { };
          description = "Metrics endpoints this host serves on loopback, by job; bastion's Prometheus scrapes its own, and a host importing `telemetry` scrapes them with Alloy and pushes them to bastion.";
        };
        probes = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "HTTPS URLs, by name, that a host importing `telemetry` probes and pushes the results of to bastion.";
        };
      };
    };

  flake.modules.nixos.telemetry =
    { config, lib, ... }:
    let
      host = config.networking.hostName;
      inherit (hosts.${host}) telemetry;
      targets = lib.concatStringsSep ",\n    " (
        lib.mapAttrsToList (
          job: port: ''{"__address__" = "127.0.0.1:${toString port}", "job" = "${job}"}''
        ) config.fleet.scrapeTargets
      );
      probes = lib.concatStringsSep ",\n    " (
        lib.mapAttrsToList (
          name: url: ''{"name" = "${name}", "address" = "${url}", "module" = "https"}''
        ) config.fleet.probes
      );
    in
    {
      services.alloy.enable = true;
      environment.etc."alloy/config.alloy".text = journal "loki.write.bastion.receiver" "{}" + ''
        loki.write "bastion" {
          endpoint {
            url = "http://${bastion}:${toString telemetry.logs}/loki/api/v1/push"
          }
        }

        prometheus.exporter.unix "node" {
          enable_collectors = ["systemd"]
        }

        discovery.relabel "node" {
          targets = prometheus.exporter.unix.node.targets
          rule {
            target_label = "job"
            replacement  = "node"
          }
        }

        prometheus.scrape "node" {
          scrape_interval = "60s"
          targets         = discovery.relabel.node.output
          forward_to      = [prometheus.relabel.instance.receiver]
        }

        prometheus.scrape "targets" {
          scrape_interval = "60s"
          targets         = [
            ${targets}
          ]
          forward_to      = [prometheus.relabel.instance.receiver]
        }

        prometheus.relabel "instance" {
          forward_to = [prometheus.remote_write.bastion.receiver]
          rule {
            target_label = "instance"
            replacement  = "${host}"
          }
        }

        prometheus.exporter.blackbox "probes" {
          config  = "{ modules: { https: { prober: http, timeout: 10s, http: { preferred_ip_protocol: ip4, fail_if_not_ssl: true } } } }"
          targets = [
            ${probes}
          ]
        }

        discovery.relabel "probes" {
          targets = prometheus.exporter.blackbox.probes.targets
          rule {
            source_labels = ["job"]
            regex         = "integrations/blackbox/(.*)"
            target_label  = "probe"
          }
          rule {
            target_label = "job"
            replacement  = "blackbox"
          }
        }

        prometheus.scrape "probes" {
          scrape_interval = "60s"
          targets         = discovery.relabel.probes.output
          forward_to      = [prometheus.remote_write.bastion.receiver]
        }

        prometheus.remote_write "bastion" {
          endpoint {
            url = "http://${bastion}:${toString telemetry.metrics}/api/v1/write"
          }
        }
      '';
    };

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
      smtp = config.services.authelia.instances.main.settings.notifier.smtp;
      adminEmails = lib.mapAttrsToList (_: person: person.email) (
        lib.filterAttrs (
          _: person: lib.elem admins person.groups
        ) (builtins.fromJSON config.sops.templates.authelia-users.content).users
      );
      grafanaSecrets = {
        grafana-oidc-client-secret = "oidc-client-secret";
        grafana-secret-key = "secret-key";
        grafana-admin-password = "admin-password";
        grafana-heartbeat-url = "heartbeat-url";
        ntfy-publisher-token = "ntfy-token";
        authelia-smtp-password = "smtp-password";
      };
      rule =
        {
          title,
          expr,
          summary,
          threshold ? 0,
          severity ? "warning",
          for ? "15m",
        }:
        {
          uid = lib.toLower (lib.replaceStrings [ " " ] [ "-" ] title);
          inherit title for;
          condition = "C";
          data = [
            {
              refId = "A";
              relativeTimeRange = {
                from = 600;
                to = 0;
              };
              datasourceUid = "prometheus";
              model = {
                inherit expr;
                instant = true;
                refId = "A";
              };
            }
            {
              refId = "C";
              datasourceUid = "__expr__";
              model = {
                type = "threshold";
                expression = "A";
                conditions = [
                  {
                    evaluator = {
                      type = "gt";
                      params = [ threshold ];
                    };
                  }
                ];
                refId = "C";
              };
            }
          ];
          noDataState = "OK";
          execErrState = "Error";
          labels.severity = severity;
          annotations.summary = summary;
        };
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
      imports = [ ntfy ];
      sops.secrets = lib.mapAttrs (
        name: _:
        lib.mkMerge [
          { restartUnits = [ "grafana.service" ]; }
          (lib.mkIf (lib.hasPrefix "grafana-" name) {
            sopsFile = ../secrets/hosts/${host}.yaml;
            key = "grafana/${lib.removePrefix "grafana-" name}";
          })
        ]
      ) grafanaSecrets;
      systemd.services.grafana.serviceConfig.LoadCredential = lib.mapAttrsToList (
        name: credential: "${credential}:${config.sops.secrets.${name}.path}"
      ) grafanaSecrets;

      services = {
        prometheus = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = ports.prometheus;
          retentionTime = "30d";
          extraFlags = [
            "--storage.tsdb.retention.size=20GB"
            "--web.enable-remote-write-receiver"
          ];
          globalConfig.scrape_interval = "60s";
          exporters.node = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = ports.node;
            enabledCollectors = [ "systemd" ];
          };
          scrapeConfigs = lib.mapAttrsToList (job: port: {
            job_name = job;
            static_configs = [
              {
                targets = [ "127.0.0.1:${toString port}" ];
                labels = {
                  instance = host;
                  inherit host;
                };
              }
            ];
          }) config.fleet.scrapeTargets;
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
            smtp = {
              enabled = true;
              host = lib.removePrefix "submissions://" smtp.address;
              user = smtp.username;
              password = "$__file{${credentials}/smtp-password}";
              from_address = smtp.username;
              from_name = "Grafana";
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
            alerting = {
              contactPoints.settings.contactPoints =
                map
                  (receiver: {
                    orgId = 1;
                    name = receiver.uid;
                    receivers = [ receiver ];
                  })
                  [
                    {
                      uid = "ntfy";
                      type = "webhook";
                      settings = {
                        url = "http://${config.services.ntfy-sh.settings.listen-http}/alerts?template=grafana";
                        authorization_scheme = "Bearer";
                        authorization_credentials = "$__file{${credentials}/ntfy-token}";
                      };
                    }
                    {
                      uid = "ntfy-critical";
                      type = "webhook";
                      settings = {
                        url = "http://${config.services.ntfy-sh.settings.listen-http}/alerts?template=grafana&priority=high";
                        authorization_scheme = "Bearer";
                        authorization_credentials = "$__file{${credentials}/ntfy-token}";
                      };
                    }
                    {
                      uid = "email";
                      type = "email";
                      settings.addresses = lib.concatStringsSep ";" adminEmails;
                    }
                    {
                      uid = "heartbeat";
                      type = "webhook";
                      settings.url = "$__file{${credentials}/heartbeat-url}";
                    }
                  ];
              policies.settings.policies = [
                {
                  orgId = 1;
                  receiver = "ntfy";
                  group_by = [ "alertname" ];
                  repeat_interval = "12h";
                  routes = [
                    {
                      receiver = "heartbeat";
                      object_matchers = [
                        [
                          "alertname"
                          "="
                          "Heartbeat"
                        ]
                      ];
                      group_wait = "0s";
                      group_interval = "1m";
                      repeat_interval = "4m";
                    }
                    {
                      receiver = "ntfy-critical";
                      object_matchers = [
                        [
                          "severity"
                          "="
                          "critical"
                        ]
                      ];
                      continue = true;
                    }
                    {
                      receiver = "email";
                      object_matchers = [
                        [
                          "severity"
                          "="
                          "critical"
                        ]
                      ];
                    }
                  ];
                }
              ];
              rules.settings.groups = [
                {
                  orgId = 1;
                  name = "fleet";
                  folder = "Fleet";
                  interval = "1m";
                  rules = map rule (
                    lib.mapAttrsToList (sender: _: {
                      title = "Host silent ${sender}";
                      expr = "absent_over_time(up{host=\"${sender}\",job=\"node\"}[10m])";
                      summary = "${sender} has sent no metrics to bastion for 10 minutes";
                    }) senders
                    ++ [
                      {
                        title = "Heartbeat";
                        expr = "vector(1)";
                        for = "0s";
                        severity = "info";
                        summary = "Always firing; healthchecks.io alerts when these stop arriving";
                      }
                      {
                        title = "Scrape target down";
                        expr = "1 - up";
                        for = "10m";
                        summary = "{{ $labels.job }} on {{ $labels.instance }} has not answered Prometheus for 10 minutes";
                      }
                      {
                        title = "Public endpoint down";
                        expr = "1 - probe_success";
                        for = "5m";
                        severity = "critical";
                        summary = "{{ $labels.probe }} has failed its HTTPS probe through the edge for 5 minutes";
                      }
                      {
                        title = "Unit failed";
                        expr = "node_systemd_unit_state{state=\"failed\"}";
                        for = "5m";
                        summary = "{{ $labels.name }} failed on {{ $labels.instance }}";
                      }
                      {
                        title = "Filesystem almost full";
                        expr = "1 - node_filesystem_avail_bytes{fstype!~\"tmpfs|ramfs|squashfs|overlay|nsfs\"} / node_filesystem_size_bytes";
                        threshold = 0.85;
                        summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} is over 85% full";
                      }
                      {
                        title = "Memory low";
                        expr = "1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes";
                        threshold = 0.9;
                        summary = "{{ $labels.instance }} has had under 10% memory available for 15 minutes";
                      }
                      {
                        title = "Out of memory kill";
                        expr = "increase(node_vmstat_oom_kill[15m])";
                        for = "0s";
                        severity = "critical";
                        summary = "The kernel killed a process for memory on {{ $labels.instance }}";
                      }
                    ]
                  );
                }
              ];
            };
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

      environment.etc."alloy/config.alloy".text =
        journal "loki.write.local.receiver" ''{ host = "${host}" }''
        + ''
          loki.write "local" {
            endpoint {
              url = "http://127.0.0.1:${toString ports.loki}/loki/api/v1/push"
            }
          }

          prometheus.remote_write "local" {
            endpoint {
              url = "http://127.0.0.1:${toString ports.prometheus}/api/v1/write"
            }
          }
        ''
        + lib.concatStrings (
          lib.mapAttrsToList (sender: telemetry: ''
            prometheus.receive_http "${sender}" {
              http {
                listen_address = "0.0.0.0"
                listen_port    = ${toString telemetry.metrics}
              }
              forward_to = [prometheus.relabel.${sender}.receiver]
            }

            prometheus.relabel "${sender}" {
              forward_to = [prometheus.remote_write.local.receiver]
              rule {
                target_label = "host"
                replacement  = "${sender}"
              }
            }

            loki.source.api "${sender}" {
              http {
                listen_address = "0.0.0.0"
                listen_port    = ${toString telemetry.logs}
              }
              labels                 = { host = "${sender}" }
              use_incoming_timestamp = true
              forward_to             = [loki.write.local.receiver]
            }
          '') (lib.mapAttrs (_: host: host.telemetry) senders)
        );
      networking.firewall.extraInputRules = lib.concatStrings (
        lib.mapAttrsToList (_: host: ''
          iifname "${config.services.tailscale.interfaceName}" ip saddr ${host.tailnetAddress} tcp dport { ${toString host.telemetry.metrics}, ${toString host.telemetry.logs} } accept
        '') senders
      );

      fleet = {
        scrapeTargets = {
          inherit (ports) node prometheus;
        };
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
