{ config, lib, ... }:
let
  inherit (config.fleet) domain hosts;
  bastion = hosts.bastion.tailnetAddress;
  senders = lib.filterAttrs (_: host: host.telemetry != null) hosts;
  metricSenders = lib.filterAttrs (_: host: host.telemetry.metrics != null) senders;
  senderPorts = telemetry: lib.remove null (lib.attrValues telemetry);
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
  httpsProbe =
    extra:
    "{ prober: http, timeout: 10s, http: { preferred_ip_protocol: ip4, fail_if_not_ssl: true${extra} } }";
  target =
    name: address: module:
    ''{"name" = "${name}", "address" = "${address}", "module" = "${module}"},'' + "\n";
  blackbox =
    {
      targets,
      forward,
      modules ? "",
      rules ? "",
    }:
    ''
      prometheus.exporter.blackbox "probes" {
        config  = "{ modules: { https: ${httpsProbe ""}${modules} } }"
        targets = [
          ${targets}
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
        ${rules}
      }

      prometheus.scrape "probes" {
        scrape_interval = "60s"
        targets         = discovery.relabel.probes.output
        forward_to      = [${forward}]
      }
    '';
  inherit (config.flake.modules.nixos) ntfy logs;
  hostname = "grafana.${domain}";
  admins = "grafana-admins";
  ports = {
    grafana = 3000;
    prometheus = 9090;
    loki = 3100;
    lokiGrpc = 9096;
    node = 19100;
    smartctl = 19633;
  };
in
{
  flake.checks =
    import ./_host-checks.nix { inherit config lib; } "alloy"
      (nixos: nixos.config.services.alloy.enable)
      (
        host: nixos:
        nixos.pkgs.runCommand "alloy-${host}" { } ''
          ${lib.getExe nixos.config.services.alloy.package} fmt ${
            nixos.config.environment.etc."alloy/config.alloy".source
          } > /dev/null
          touch $out
        ''
      );

  flake.modules.nixos.base =
    { lib, ... }:
    {
      options.fleet = {
        scrapeTargets = lib.mkOption {
          type = lib.types.attrsOf lib.types.port;
          default = { };
          description = "Metrics endpoints this host serves on loopback, by job; bastion's Prometheus scrapes its own, and a host importing `telemetry` scrapes them with Alloy and pushes them to bastion.";
        };
        metricsDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/node-exporter-textfile";
          description = "Directory whose *.prom files the node exporter publishes, for jobs that record their own results, such as a backup's last success.";
        };
        probes = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "HTTPS URLs, by name, that a host importing `telemetry` probes and pushes the results of to bastion.";
        };
      };
    };

  flake.modules.nixos.logs =
    { config, ... }:
    {
      services.alloy.enable = true;
      environment.etc."alloy/config.alloy".text = journal "loki.write.bastion.receiver" "{}" + ''
        loki.write "bastion" {
          endpoint {
            url                 = "http://${bastion}:${
              toString hosts.${config.networking.hostName}.telemetry.logs
            }/loki/api/v1/push"
            max_backoff_retries = 0
          }
        }
      '';
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/private/alloy";
          configureParent = true;
          parent.mode = "0700";
        }
      ];
    };

  flake.modules.nixos.telemetry =
    { config, lib, ... }:
    let
      host = config.networking.hostName;
      inherit (hosts.${host}) telemetry;
      targets = lib.concatMapStrings (item: item + ",\n    ") (
        lib.mapAttrsToList (
          job: port: ''{"__address__" = "127.0.0.1:${toString port}", "job" = "${job}"}''
        ) config.fleet.scrapeTargets
      );
    in
    {
      imports = [ logs ];
      environment.etc."alloy/config.alloy".text = ''
        prometheus.exporter.unix "node" {
          enable_collectors = ["systemd"]

          systemd {
            enable_restarts = true
          }
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

        prometheus.remote_write "bastion" {
          endpoint {
            url = "http://${bastion}:${toString telemetry.metrics}/api/v1/metrics/write"
          }
        }
      ''
      + blackbox {
        targets = lib.concatStrings (
          lib.mapAttrsToList (name: url: target name url "https") config.fleet.probes
        );
        forward = "prometheus.relabel.instance.receiver";
      };
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
      inherit (hosts.${host}) lan;
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
          datasource ? "prometheus",
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
              datasourceUid = datasource;
              model = lib.filterAttrs (_: value: value != null) {
                inherit expr;
                instant = if datasource == "prometheus" then true else null;
                queryType = if datasource == "loki" then "instant" else null;
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
      # grafana.com dashboards by id: Node Exporter Full, SMARTctl Exporter Dashboard, APC UPS Dashboard (apcupsd), CrowdSec Metrics, Caddy
      dashboards =
        lib.mapAttrs
          (
            name: pin:
            pkgs.runCommand "${name}.json" { } ''
              sed 's/''${DS_PROMETHEUS}/prometheus/g' ${
                pkgs.fetchurl {
                  url = "https://grafana.com/api/dashboards/${toString pin.id}/revisions/${toString pin.revision}/download";
                  inherit (pin) hash;
                }
              } > $out
            ''
          )
          {
            node-exporter-full = {
              id = 1860;
              revision = 46;
              hash = "sha256-5Y3cXcU11MkB+U2pZIvD49Wue2946Y4YW86LKJlhzqM=";
            };
            smartctl = {
              id = 22604;
              revision = 4;
              hash = "sha256-ah36BdFIcaprUz39hRzuYVzfp3diEBckmalMaOls5kY=";
            };
            apcupsd = {
              id = 21119;
              revision = 1;
              hash = "sha256-ghzogIn98S41t1swJ0E0Fo4Wxmv7Vk4YfJ1wGmcnaQg=";
            };
            crowdsec = {
              id = 21419;
              revision = 6;
              hash = "sha256-4fbSv6UwYaEEwV0WH4U63ulu9/diQR72nIrlKPr+77U=";
            };
            caddy = {
              id = 22870;
              revision = 3;
              hash = "sha256-T/oImuRQrEGWLlaaMnBVNFNeAoKR1j1IiDoAlGmYnPU=";
            };
          };
    in
    {
      imports = [ ntfy ];
      sops.secrets = lib.mapAttrs (
        name: _:
        lib.mkMerge [
          { restartUnits = [ "grafana.service" ]; }
          (lib.mkIf (lib.hasPrefix "grafana-" name) {
            key = "grafana/${lib.removePrefix "grafana-" name}";
          })
        ]
      ) grafanaSecrets;
      systemd.services.grafana.serviceConfig.LoadCredential = lib.mapAttrsToList (
        name: credential: "${credential}:${config.sops.secrets.${name}.path}"
      ) grafanaSecrets;

      services = {
        udev.extraRules = ''
          SUBSYSTEM=="nvme", KERNEL=="nvme[0-9]*", GROUP="disk", MODE="0660"
        '';
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
          exporters.smartctl = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = ports.smartctl;
          };
          exporters.node = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = ports.node;
            enabledCollectors = [
              "systemd"
              "textfile"
            ];
            extraFlags = [
              "--collector.textfile.directory=${config.fleet.metricsDir}"
              "--collector.systemd.enable-restarts-metrics"
            ];
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
            frontend.address = "127.0.0.1";
            limits_config.retention_period = "720h";
            compactor = {
              working_directory = "${config.services.loki.dataDir}/compactor";
              retention_enabled = true;
              delete_request_store = "filesystem";
            };
            analytics.reporting_enabled = false;
          };
        };

        alloy = {
          enable = true;
          # shortcut: Alloy's raw syslog format is experimental, drop the flag once it is stable or the gateway's lines parse as rfc3164
          extraFlags = lib.optional (lan != null) "--stability.level=experimental";
        };

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
                options.path = pkgs.linkFarm "dashboards" (
                  lib.mapAttrs' (name: json: lib.nameValuePair "${name}.json" json) dashboards
                );
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
                      for = "2m";
                      severity = "critical";
                      summary = "${sender} has sent no metrics to bastion for 10 minutes";
                    }) metricSenders
                    ++ lib.mapAttrsToList (sender: _: {
                      title = "Logs silent ${sender}";
                      datasource = "loki";
                      expr = "absent_over_time({host=\"${sender}\"}[30m])";
                      summary = "${sender} has delivered no logs to bastion for 45 minutes";
                    }) metricSenders
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
                        summary = "{{ $labels.probe }} has failed its HTTPS probe from {{ $labels.instance }} for 5 minutes";
                      }
                      {
                        title = "Certificate expiring";
                        expr = "7 * 86400 - (probe_ssl_earliest_cert_expiry - time())";
                        for = "1h";
                        summary = "The certificate {{ $labels.probe }} serves expires in under 7 days";
                      }
                      {
                        title = "SMART unhealthy";
                        expr = "(1 - smartctl_device_smart_status) and on (device, instance) smartctl_device_power_on_seconds";
                        for = "0s";
                        severity = "critical";
                        summary = "{{ $labels.device }} on {{ $labels.instance }} fails its SMART self-assessment";
                      }
                      {
                        title = "Disk unmonitored";
                        expr = "(count by (instance) (node_disk_info{device=~\"sd[a-z]+|nvme[0-9]+n1\"}) - (count by (instance) (smartctl_device) or count by (instance) (node_disk_info) * 0)) and on (instance) up{job=\"smartctl\"}";
                        for = "1h";
                        summary = "Disks on {{ $labels.instance }} report no SMART data to the smartctl exporter";
                      }
                      {
                        title = "NVMe hot";
                        expr = "smartctl_device_temperature{temperature_type=\"current\",device=~\"nvme.*\"}";
                        threshold = 70;
                        summary = "{{ $labels.device }} on {{ $labels.instance }} has been over 70°C for 15 minutes";
                      }
                      {
                        title = "Disk hot";
                        expr = "smartctl_device_temperature{temperature_type=\"current\",device!~\"nvme.*\"}";
                        threshold = 55;
                        summary = "{{ $labels.device }} on {{ $labels.instance }} has been over 55°C for 15 minutes";
                      }
                      {
                        title = "ZFS pool not online";
                        expr = "sum by (zpool, instance) (node_zfs_zpool_state{state!=\"online\"})";
                        for = "5m";
                        severity = "critical";
                        summary = "ZFS pool {{ $labels.zpool }} on {{ $labels.instance }} is not online";
                      }
                      {
                        title = "UPS on battery";
                        expr = "apcupsd_battery_time_on_seconds";
                        for = "1m";
                        severity = "critical";
                        summary = "{{ $labels.instance }} has been on UPS battery for over a minute";
                      }
                      {
                        title = "Backup stale";
                        expr = "time() - restic_last_success_timestamp_seconds{backup!~\"drill-usb|thinkpad\"}";
                        threshold = 30 * 3600;
                        summary = "The {{ $labels.backup }} backup on {{ $labels.instance }} has not succeeded for over 30 hours";
                      }
                      {
                        title = "Laptop backup stale";
                        expr = "time() - restic_last_success_timestamp_seconds{backup=\"thinkpad\"}";
                        threshold = 3 * 86400;
                        summary = "The ThinkPad has not uploaded a home backup to {{ $labels.instance }} for over 3 days";
                      }
                      {
                        title = "Restore drill stale";
                        expr = "time() - restic_last_success_timestamp_seconds{backup=\"drill-usb\"}";
                        threshold = 40 * 86400;
                        summary = "The monthly restore drill on {{ $labels.instance }} has not succeeded for over 40 days";
                      }
                      {
                        title = "Proxy server errors";
                        expr = "(sum by (instance) (increase(caddy_http_request_duration_seconds_count{code=~\"5..\"}[15m])) > 10) / sum by (instance) (increase(caddy_http_request_duration_seconds_count[15m]))";
                        threshold = 0.1;
                        summary = "Caddy on {{ $labels.instance }} answered more than 10% of requests, and more than 10 in all, with a server error for 15 minutes";
                      }
                      {
                        title = "Arr health issue";
                        expr = "sum by (job, source) ({__name__=~\"(sonarr|radarr|prowlarr)_system_health_issues\", source!=\"UpdateCheck\"})";
                        for = "1h";
                        summary = "{{ $labels.job }} has failed its {{ $labels.source }} health check for over an hour; its System page names what";
                      }
                      {
                        title = "Gateway security event";
                        datasource = "loki";
                        expr = "sum by (name) (count_over_time({host=\"gateway\"} |= \"UNIFIcategory=Security\" != \"|Blocked by Firewall|\" | regexp `CEF:0\\|[^|]*\\|[^|]*\\|[^|]*\\|[^|]*\\|(?P<name>[^|]*)\\|` [10m]))";
                        for = "0s";
                        summary = "The UniFi gateway reported {{ $labels.name }} (IPS or honeypot); details in Loki under host=gateway";
                      }
                      {
                        title = "Unit failed";
                        expr = "node_systemd_unit_state{state=\"failed\"}";
                        for = "5m";
                        summary = "{{ $labels.name }} failed on {{ $labels.instance }}";
                      }
                      {
                        title = "Unit restarting";
                        expr = "round(increase(node_systemd_service_restart_total[30m]))";
                        threshold = 3;
                        for = "0s";
                        summary = "{{ $labels.name }} on {{ $labels.instance }} restarted more than 3 times in 30 minutes";
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
      fleet.loopbackGuards = lib.mkMerge [
        {
          monitoring = {
            ports =
              lib.attrValues config.fleet.scrapeTargets
              ++ [
                ports.loki
                ports.lokiGrpc
              ]
              ++ lib.concatMap (sender: senderPorts sender.telemetry) (lib.attrValues senders);
            users = [
              "root"
              "grafana"
              "prometheus"
              "loki"
              "alloy"
            ];
          };
        }
        (lib.mkIf (lan != null) {
          gateway-syslog = {
            ports = [ lan.syslogPort ];
            protocol = "udp";
            users = [ ];
          };
        })
      ];

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
        + blackbox {
          modules = ", public: ${
            httpsProbe ", headers: { Host: auth.${domain} }, tls_config: { server_name: auth.${domain} }"
          }";
          targets =
            target "lan-proxy" "https://auth.${domain}" "https"
            + lib.concatStrings (
              lib.mapAttrsToList (name: public: target "public-${name}" "https://${public.publicAddress}" "public") (
                lib.filterAttrs (_: other: other.publicAddress != null) hosts
              )
            );
          rules = ''
            rule {
              target_label = "instance"
              replacement  = "${host}"
            }
            rule {
              target_label = "host"
              replacement  = "${host}"
            }
          '';
          forward = "prometheus.remote_write.local.receiver";
        }
        + lib.concatStrings (
          lib.mapAttrsToList (
            sender: telemetry:
            lib.optionalString (telemetry.metrics != null) ''
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
            ''
            + ''
              loki.source.api "${sender}" {
                http {
                  listen_address = "0.0.0.0"
                  listen_port    = ${toString telemetry.logs}
                }
                labels                 = { host = "${sender}" }
                use_incoming_timestamp = true
                forward_to             = [loki.write.local.receiver]
              }
            ''
          ) (lib.mapAttrs (_: host: host.telemetry) senders)
        )
        + lib.optionalString (lan != null) ''
          loki.source.syslog "gateway" {
            listener {
              address       = "0.0.0.0:${toString lan.syslogPort}"
              protocol      = "udp"
              syslog_format = "raw"
              labels        = { host = "gateway" }
            }
            forward_to = [loki.write.local.receiver]
          }
        '';
      networking.firewall.extraInputRules =
        lib.concatStrings (
          lib.mapAttrsToList (_: host: ''
            iifname "${config.services.tailscale.interfaceName}" ip saddr ${host.tailnetAddress} tcp dport { ${
              lib.concatMapStringsSep ", " toString (senderPorts host.telemetry)
            } } accept
          '') senders
        )
        + lib.optionalString (lan != null) ''
          ip saddr ${lan.gateway} ip daddr ${lan.address} udp dport ${toString lan.syslogPort} accept
        '';

      fleet = {
        scrapeTargets = {
          inherit (ports) node prometheus smartctl;
        };
        web.apps.grafana.port = ports.grafana;
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

      systemd.tmpfiles.rules = [ "d ${config.fleet.metricsDir} 0755 root root -" ];
      preservation.preserveAt."/persist".directories = [
        {
          directory = config.fleet.metricsDir;
          mode = "0755";
        }
      ]
      ++
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
