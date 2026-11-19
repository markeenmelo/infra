{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) downloads nixflix postgresql;
  inherit (config.fleet) domain;
  net = import ./_downloads.nix;
  hostSecrets = "/run/downloads-secrets";
  guestSecrets = "/run/host-secrets";
  guestDumps = "/var/backup/postgresql";
  exporterPorts = {
    sonarr = 19708;
    radarr = 19709;
    prowlarr = 19710;
  };
  seerrApps = [
    "sonarr"
    "radarr"
  ];
  apps = [
    "sonarr"
    "radarr"
    "prowlarr"
  ];
  indexers = [
    "Knaben"
    "The Pirate Bay"
    "YTS"
    "Nyaa.si"
  ];
  easynewsPort = 8084;
  usenetIndexers = [
    {
      name = "NinjaCentral";
      baseUrl = "https://ninjacentral.co.za";
    }
    {
      name = "NZBgeek";
      baseUrl = "https://api.nzbgeek.info";
    }
    {
      name = "altHUB";
      baseUrl = "https://api.althub.co.za";
    }
    {
      name = "Easynews";
      schemaName = "Generic Newznab";
      baseUrl = "http://127.0.0.1:${toString easynewsPort}";
    }
  ];
  usenetServers = [
    {
      name = "Newshosting";
      host = "news.newshosting.com";
      connections = 100;
      priority = 0;
      retention = 6625;
    }
    {
      name = "Tweaknews";
      host = "newshosting.tweaknews.eu";
      connections = 40;
      priority = 1;
      retention = 4200;
    }
  ];
  storageProfile = "1080p Storage Efficient";
  storageQualities = [
    "WEBDL-1080p"
    "WEBRip-1080p"
    "Bluray-1080p"
  ];
  # ProtonVPN's NAT-PMP gateway inside the tunnel
  protonGateway = "10.2.0.1";

  guest =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      vpn = config.nixflix.vpn.namespace;
      inherit (config.vpnNamespaces.${vpn}) namespaceAddress;
      qbittorrent = config.nixflix.torrentClients.qbittorrent;
      inherit (config.services.qbittorrent) webuiPort;
      sabnzbd = config.nixflix.usenetClients.sabnzbd;
      secret = name: { _secret = "${guestSecrets}/${name}"; };
      appPort = name: config.nixflix.${name}.config.hostConfig.port;
      confined = {
        enable = true;
        vpnNamespace = vpn;
      };
      media = dirOf config.nixflix.mediaDir;
      withoutResponseBody =
        unit: rewrites:
        let
          script =
            (import "${inputs.nixflix}/modules/prowlarr/${unit}.nix" { inherit config lib pkgs; })
            .config.systemd.services."prowlarr-${unit}".content.script;
          dump = ''cat "$RESPONSE_FILE"'';
          from = [ dump ] ++ lib.attrNames rewrites;
        in
        assert lib.hasInfix dump script;
        assert lib.all (part: lib.length (lib.splitString part script) == 2) (lib.attrNames rewrites);
        lib.mkForce (
          lib.replaceStrings from (
            [ ''echo "Response body omitted: it may echo API keys."'' ] ++ lib.attrValues rewrites
          ) script
        );
      decluttarrApps = seerrApps;
      decluttarrEnv = map (name: "${lib.toUpper name}_API_KEY") (decluttarrApps ++ [ "sabnzbd" ]) ++ [
        "QBITTORRENT_PASSWORD"
      ];
      envTag = name: "@ENV:${name}@";
      decluttarrConfig = pkgs.writeText "decluttarr.yaml" (
        lib.replaceStrings (map (name: ''"${envTag name}"'') decluttarrEnv)
          (map (name: "!ENV ${name}") decluttarrEnv)
          (
            builtins.toJSON {
              general = {
                test_run = false;
              };
              job_defaults.max_strikes = 5;
              jobs = {
                remove_bad_files = true;
                remove_failed_imports.message_patterns = [
                  "*Found potentially dangerous file with extension*"
                  "Invalid video file*"
                  "No files found are eligible for import*"
                ];
                remove_failed_downloads = true;
                remove_metadata_missing = true;
                remove_stalled = true;
                remove_slow = true;
                remove_missing_files = true;
                remove_orphans = true;
                remove_done_seeding.target_categories = decluttarrApps;
                search_missing = true;
                search_unmet_cutoff = true;
                detect_deletions = true;
              };
              instances = lib.genAttrs decluttarrApps (name: [
                {
                  base_url = "http://${namespaceAddress}:${toString (appPort name)}";
                  api_key = envTag "${lib.toUpper name}_API_KEY";
                }
              ]);
              download_clients = {
                qbittorrent = [
                  {
                    base_url = "http://${namespaceAddress}:${toString webuiPort}";
                    username = "marcos";
                    password = envTag "QBITTORRENT_PASSWORD";
                  }
                ];
                sabnzbd = [
                  {
                    base_url = "http://${namespaceAddress}:${toString sabnzbd.settings.misc.port}";
                    api_key = envTag "SABNZBD_API_KEY";
                  }
                ];
              };
            }
          )
      );
      storageEfficient = {
        quality_profiles = lib.mkDefault (
          lib.mkAfter [
            {
              name = storageProfile;
              min_format_score = 0;
              reset_unmatched_scores.enabled = true;
              upgrade = {
                allowed = false;
                until_quality = "1080p";
              };
              qualities = [
                {
                  name = "1080p";
                  qualities = storageQualities;
                }
              ];
            }
          ]
        );
        quality_definition.qualities = map (name: {
          inherit name;
          min = 0;
          preferred = 30;
          max = 31.7;
        }) storageQualities;
      };
    in
    {
      imports = [ nixflix ];
      nixflix = lib.mkMerge [
        {
          postgres.enable = true;
          vpn = {
            enable = true;
            wgConfFile = "${guestSecrets}/proton-wireguard";
            allowedIngress = [ net.hostAddress ];
          };
          torrentClients.qbittorrent = {
            enable = true;
            vpn.enable = true;
            profileDir = "${config.nixflix.stateDir}/qbittorrent";
            password = secret "qbittorrent-password";
            serverConfig = {
              BitTorrent.Session = {
                QueueingSystemEnabled = true;
                IgnoreSlowTorrentsForQueueing = true;
                SlowTorrentsDownloadRate = 2;
                SlowTorrentsUploadRate = 2;
                SlowTorrentsInactivityTimer = 60;
                MaxActiveDownloads = 10;
                MaxActiveTorrents = 20;
                MaxActiveUploads = 10;
                GlobalMaxRatio = 0.5;
                GlobalMaxSeedingMinutes = 30;
                GlobalUPSpeedLimit = 500;
                ReannounceWhenAddressChanged = true;
              };
              Preferences.WebUI = {
                Username = "marcos";
                ServerDomains = "qbittorrent.${domain}";
              };
            };
          };
          usenetClients.sabnzbd = {
            enable = true;
            settings = {
              misc = {
                api_key = secret "sabnzbd-api-key";
                nzb_key = secret "sabnzbd-nzb-key";
                username = "marcos";
                password = secret "password";
                host_whitelist = "sabnzbd.${domain}";
                admin_dir = "${config.nixflix.stateDir}/sabnzbd/admin";
                log_dir = "${config.nixflix.stateDir}/sabnzbd/logs";
                unwanted_extensions = "exe, scr, com, bat, cmd, lnk, msi, vbs, ps1";
                action_on_unwanted_extensions = 2;
              };
              servers = map (server: {
                inherit (server)
                  name
                  host
                  connections
                  priority
                  retention
                  ;
                ssl_verify = "strict";
                username = secret "${lib.toLower server.name}-username";
                password = secret "newshosting-password";
              }) usenetServers;
            };
          };
          recyclarr = {
            enable = true;
            config = lib.genAttrs decluttarrApps (name: {
              ${name} = storageEfficient;
            });
          };
          prowlarr.config.indexers =
            map (name: {
              inherit name;
              enable = true;
              "torrentBaseSettings.appMinimumSeeders" = 5;
            }) indexers
            ++ map (
              indexer:
              lib.mkMerge [
                indexer
                {
                  enable = true;
                  priority = 10;
                  apiKey = secret "${lib.toLower indexer.name}-api-key";
                }
              ]
            ) usenetIndexers;
        }
        (lib.genAttrs apps (name: {
          enable = true;
          vpn.enable = true;
          settings.server.bindaddress = namespaceAddress;
          config = {
            apiKey = secret "${name}-api-key";
            hostConfig = {
              username = "marcos";
              password = secret "password";
              authenticationRequired = "enabled";
            };
          };
        }))
      ];
      # the uid that owns qbittorrent's state, allocated by the old generation; nixflix forces the whole account, so it is restated
      users.users.qbittorrent = lib.mkOverride 49 {
        uid = 988;
        isSystemUser = true;
        inherit (config.services.qbittorrent) group;
      };
      services.postgresqlBackup = {
        enable = true;
        databases = apps;
        location = guestDumps;
        pgdumpOptions = "--no-owner --no-privileges --lock-wait-timeout=5min";
      };
      systemd.services = lib.mkMerge [
        (lib.genAttrs (map (name: "postgresqlBackup-${name}") apps) (name: {
          requires = [ "arr-restore.service" ];
          after = [ "arr-restore.service" ];
          serviceConfig.ExecCondition = pkgs.writeShellScript "${name}-has-tables" ''
            tables=$(${lib.getExe' config.services.postgresql.package "psql"} -d ${lib.removePrefix "postgresqlBackup-" name} -Atc "select count(*) from pg_tables where schemaname = 'public'") || exit 1
            [ "$tables" != 0 ]
          '';
        }))
        (lib.genAttrs
          (
            apps
            ++ [
              "qbittorrent"
              "sabnzbd"
              "decluttarr"
            ]
          )
          (_: {
            unitConfig.RequiresMountsFor = [
              config.nixflix.stateDir
              media
            ];
          })
        )
        {
          arr-restore = {
            description = "Load each arr database from its last dump while it is empty";
            requiredBy = map (name: "${name}.service") apps;
            before = map (name: "${name}.service") apps;
            requires = [ "postgresql-setup.service" ];
            after = [ "postgresql-setup.service" ];
            unitConfig.RequiresMountsFor = [ guestDumps ];
            path = [
              config.services.postgresql.package
              pkgs.gzip
              pkgs.util-linux
            ];
            enableStrictShellChecks = true;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              set -o pipefail
              for db in ${lib.concatStringsSep " " apps}; do
                dump=${guestDumps}/$db.sql.gz
                [ -e "$dump" ] || dump=${guestDumps}/$db.prev.sql.gz
                [ -e "$dump" ] || continue
                tables=$(runuser -u "$db" -- psql -d "$db" -Atc "select count(*) from pg_tables where schemaname = 'public'")
                [ "$tables" = 0 ] || continue
                echo "Loading $db from $dump"
                gunzip -c "$dump" | runuser -u "$db" -- psql -v ON_ERROR_STOP=1 --single-transaction -d "$db" > /dev/null
              done
            '';
          };
          prowlarr-indexers = {
            wants = [ "easynews-indexer.service" ];
            after = [ "easynews-indexer.service" ];
            script = withoutResponseBody "indexers" {
              "exit \"$RC\"" =
                ''[ "$RC" -eq 0 ] || echo "<4>Some indexers failed to apply; see the errors above."'';
            };
          };
          prowlarr-applications.script = withoutResponseBody "applications" { };
          recyclarr.vpnConfinement = confined;
          decluttarr = {
            description = "Clean the arr queues and download clients, and search for missing media";
            after = map (name: "${name}.service") (
              decluttarrApps
              ++ [
                "qbittorrent"
                "sabnzbd"
              ]
            );
            wantedBy = [ "multi-user.target" ];
            vpnConfinement = confined;
            enableStrictShellChecks = true;
            serviceConfig = {
              DynamicUser = true;
              SupplementaryGroups = [ config.nixflix.globals.libraryOwner.group ];
              Restart = "on-failure";
              RestartSec = "30s";
              StateDirectory = "decluttarr";
              WorkingDirectory = "%S/decluttarr";
              LoadCredential =
                map (name: "${name}:${guestSecrets}/${name}") (
                  map (name: "${name}-api-key") (decluttarrApps ++ [ "sabnzbd" ])
                )
                ++ [ "QBITTORRENT_PASSWORD:${guestSecrets}/qbittorrent-password" ];
            };
            script = ''
              mkdir -p config
              ln -sfn ${decluttarrConfig} config/config.yaml
              ${lib.concatMapStrings (name: ''
                ${lib.toUpper name}_API_KEY=$(< "$CREDENTIALS_DIRECTORY/${name}-api-key")
                export ${lib.toUpper name}_API_KEY
              '') (decluttarrApps ++ [ "sabnzbd" ])}
              QBITTORRENT_PASSWORD=$(< "$CREDENTIALS_DIRECTORY/QBITTORRENT_PASSWORD")
              export QBITTORRENT_PASSWORD
              exec ${lib.getExe (pkgs.callPackage ./decluttarr.pkg.nix { })}
            '';
          };
          sabnzbd-categories = {
            wantedBy = [ "sabnzbd.service" ];
            partOf = [ "sabnzbd.service" ];
          };
          easynews-indexer = {
            description = "Easynews search as a Newznab indexer for Prowlarr";
            wantedBy = [ "multi-user.target" ];
            vpnConfinement = confined;
            enableStrictShellChecks = true;
            serviceConfig = {
              DynamicUser = true;
              Restart = "on-failure";
              RestartSec = "5s";
              LoadCredential = map (name: "${name}:${guestSecrets}/${name}") [
                "newshosting-username"
                "easynews-password"
                "easynews-api-key"
              ];
            };
            script = ''
              EASYNEWS_USER="$(< "$CREDENTIALS_DIRECTORY/newshosting-username")@newshosting.com"
              EASYNEWS_PASS=$(< "$CREDENTIALS_DIRECTORY/easynews-password")
              NEWZNAB_APIKEY=$(< "$CREDENTIALS_DIRECTORY/easynews-api-key")
              export EASYNEWS_USER EASYNEWS_PASS NEWZNAB_APIKEY
              exec ${lib.getExe (pkgs.callPackage ./easynews-indexer.pkg.nix { })} \
                --bind 127.0.0.1:${toString easynewsPort} --threads 4
            '';
          };
          qbittorrent.serviceConfig = {
            Restart = "on-failure";
            RestartSec = "5s";
            LoadCredential = [
              "webui-password-hash:${guestSecrets}/qbittorrent-password-hash"
            ];
            ExecStartPre = lib.mkAfter [
              (lib.getExe (
                pkgs.writeShellApplication {
                  name = "qbittorrent-webui-password";
                  runtimeInputs = [ pkgs.gawk ];
                  text = ''
                    umask 077
                    conf=${qbittorrent.profileDir}/qBittorrent/config/qBittorrent.conf
                    HASH=$(< "$CREDENTIALS_DIRECTORY/webui-password-hash") awk '
                      /^WebUI\\Password_PBKDF2=/ { next }
                      { print }
                      /^\[Preferences\]$/ { print "WebUI\\Password_PBKDF2=" ENVIRON["HASH"] }
                    ' "$conf" > "$conf.new"
                    mv "$conf.new" "$conf"
                  '';
                }
              ))
            ];
          };
          qbittorrent-port-forward = {
            description = "Keep ProtonVPN's forwarded port open for qBittorrent";
            after = [
              "${vpn}.service"
              "qbittorrent.service"
            ];
            requires = [ "${vpn}.service" ];
            bindsTo = [ "qbittorrent.service" ];
            wantedBy = [ "qbittorrent.service" ];
            path = [
              pkgs.curl
              pkgs.iproute2
              pkgs.iptables
              pkgs.libnatpmp
              pkgs.gawk
            ];
            enableStrictShellChecks = true;
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "5s";
              RuntimeDirectory = "qbittorrent-port-forward";
              RuntimeDirectoryMode = "0700";
              UMask = "0077";
              LoadCredential = [ "password:${guestSecrets}/qbittorrent-password" ];
            };
            script = ''
              api=http://${namespaceAddress}:${toString webuiPort}/api/v2
              cookies=$RUNTIME_DIRECTORY/cookies
              current=""
              fw() { ip netns exec ${vpn} iptables "$@"; }
              fw -N qbittorrent-port 2>/dev/null || true
              fw -C INPUT -j qbittorrent-port 2>/dev/null || fw -I INPUT -j qbittorrent-port
              open_port() {
                fw -F qbittorrent-port || return
                for proto in tcp udp; do
                  fw -A qbittorrent-port -i ${vpn}0 -p "$proto" --dport "$1" -j ACCEPT || return
                done
              }
              set_port() {
                curl -fsS -c "$cookies" --data-urlencode username=marcos \
                  --data-urlencode "password@$CREDENTIALS_DIRECTORY/password" "$api/auth/login" > /dev/null &&
                  curl -fsS -b "$cookies" --data "json={\"listen_port\":$1,\"random_port\":false}" "$api/app/setPreferences" &&
                  curl -fsS -b "$cookies" --data hashes=all "$api/torrents/reannounce"
              }
              while true; do
                port=$(ip netns exec ${vpn} natpmpc -a 1 0 udp 60 -g ${protonGateway} | awk '/Mapped public port/ { print $4 }' || true)
                ip netns exec ${vpn} natpmpc -a 1 0 tcp 60 -g ${protonGateway} > /dev/null || true
                if [ -z "$port" ]; then
                  echo "No port from ${protonGateway}; is the tunnel up?"
                  sleep 5
                  continue
                fi
                if [ "$port" != "$current" ]; then
                  echo "Forwarded port $current -> $port"
                  if ! { open_port "$port" && set_port "$port"; }; then
                    sleep 5
                    continue
                  fi
                  current=$port
                fi
                sleep 45
              done
            '';
          };
        }
      ];
    };

  host =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      guestSystem = config.microvm.vms.downloads.config;
      guestConfig = guestSystem.config;
      appPort = name: guestConfig.nixflix.${name}.config.hostConfig.port;
      secret = name: config.sops.secrets."arr-${name}".path;
      hostUnits = {
        sonarr-api-key = [
          "prometheus-exportarr-sonarr-exporter"
          "seerr"
        ];
        radarr-api-key = [
          "prometheus-exportarr-radarr-exporter"
          "seerr"
        ];
        prowlarr-api-key = [ "prometheus-exportarr-prowlarr-exporter" ];
        seerr-api-key = [ "seerr" ];
      };
      guestHeld = [
        "sonarr-api-key"
        "radarr-api-key"
        "prowlarr-api-key"
        "password"
        "sabnzbd-api-key"
        "sabnzbd-nzb-key"
        "newshosting-username"
        "newshosting-password"
        "tweaknews-username"
        "easynews-password"
        "easynews-api-key"
        "ninjacentral-api-key"
        "nzbgeek-api-key"
        "althub-api-key"
        "qbittorrent-password"
        "qbittorrent-password-hash"
        "proton-wireguard"
      ];
      hostDumps = "${dirOf config.services.postgresqlBackup.location}/downloads";
      handover = "${hostDumps}-handover";
      install = lib.getExe' pkgs.coreutils "install";
      awaitProfile =
        name:
        pkgs.writeShellApplication {
          name = "await-${name}-profile";
          runtimeInputs = [
            pkgs.curl
            pkgs.jq
          ];
          text = ''
            while (( SECONDS < 180 )); do
              if curl -fsS --max-time 5 -H @<(printf 'X-Api-Key: %s' "$(< ${secret "${name}-api-key"})") \
                http://${net.guestAddress}:${toString (appPort name)}/api/v3/qualityprofile |
                jq -e --arg profile ${lib.escapeShellArg storageProfile} 'any(.[]; .name == $profile)' > /dev/null; then
                exit 0
              fi
              sleep 5
            done
            echo "${name} in the downloads guest has no profile ${storageProfile} after 3 minutes" >&2
            exit 1
          '';
        };
      toGuest =
        name: uids:
        ''ct state new oifname "${net.tap}" meta skuid { ${
          lib.concatMapStringsSep ", " toString uids
        } } tcp dport { ${lib.concatMapStringsSep ", " (app: toString (appPort app)) name} } accept'';
    in
    {
      imports = [
        downloads
        nixflix
        postgresql
      ];

      microvm.vms.downloads.config = {
        imports = [ guest ];
        services.postgresql.package = config.services.postgresql.package;
        time.timeZone = config.time.timeZone;
        microvm.shares = [
          {
            proto = "virtiofs";
            tag = "secrets";
            source = hostSecrets;
            mountPoint = guestSecrets;
            readOnly = true;
          }
          {
            proto = "virtiofs";
            tag = "dumps";
            source = hostDumps;
            mountPoint = guestDumps;
          }
        ];
      };

      sops.secrets = lib.listToAttrs (
        map (
          name:
          lib.nameValuePair "arr-${name}" {
            key = "arr/${name}";
            restartUnits = map (unit: "${unit}.service") (
              hostUnits.${name} or [ ] ++ lib.optional (lib.elem name guestHeld) "microvm-virtiofsd@downloads"
            );
          }
        ) (lib.unique (lib.attrNames hostUnits ++ guestHeld))
      );

      nixflix = {
        postgres.enable = true;
        seerr = lib.mkMerge [
          {
            enable = true;
            vpn.enable = false;
            apiKey._secret = secret "seerr-api-key";
          }
          (lib.genAttrs seerrApps (
            name:
            let
              instance = lib.head (lib.attrNames guestSystem.options.nixflix.seerr.${name}.default);
            in
            lib.mkMerge [
              guestSystem.options.nixflix.seerr.${name}.default
              {
                ${instance} = {
                  hostname = lib.mkForce net.guestAddress;
                  apiKey = lib.mkForce { _secret = secret "${name}-api-key"; };
                  activeProfileName = storageProfile;
                };
              }
            ]
          ))
        ];
      };

      users.users.exportarr = {
        isSystemUser = true;
        uid = 357;
        group = "exportarr";
      };
      users.groups.exportarr.gid = 357;
      services.prometheus.exporters = lib.listToAttrs (
        map (
          name:
          lib.nameValuePair "exportarr-${name}" {
            enable = true;
            url = "http://${net.guestAddress}:${toString (appPort name)}";
            apiKeyFile = secret "${name}-api-key";
            environment.INTERFACE = "127.0.0.1";
            port = exporterPorts.${name};
            user = "exportarr";
            group = "exportarr";
          }
        ) apps
      );
      fleet.scrapeTargets = lib.mapAttrs' (
        name: port: lib.nameValuePair "exportarr-${name}" port
      ) exporterPorts;
      fleet.web.apps = lib.mkMerge [
        (lib.genAttrs apps (name: {
          port = appPort name;
          address = net.guestAddress;
        }))
        {
          qbittorrent = {
            port = guestConfig.services.qbittorrent.webuiPort;
            address = net.guestAddress;
          };
          sabnzbd = {
            inherit (guestConfig.nixflix.usenetClients.sabnzbd.settings.misc) port;
            address = net.guestAddress;
          };
          seerr = { inherit (config.nixflix.seerr) port; };
        }
      ];
      nixpkgs.config.allowUnfreePackages = [ "unrar" ];
      system.activationScripts.arr-handover.text = ''
        if [ -e /run/current-system/etc/systemd/system/${lib.head apps}.service ] &&
          [ -n "$(find ${handover}/done -mtime -7 2> /dev/null)" ]; then
          mkdir -p ${handover}/replaced
          mv -f ${hostDumps}/*.sql.gz ${handover}/replaced/ 2> /dev/null || true
          if [ -e ${config.microvm.stateDir}/downloads/var.img ]; then
            mv -f ${config.microvm.stateDir}/downloads/var.img ${config.microvm.stateDir}/downloads/var.img.replaced
          fi
          rm -f ${handover}/done
        fi
      '';
      networking.nftables.tables.arr = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority -150; policy accept;
            ${toGuest seerrApps [ config.users.users.${config.nixflix.seerr.user}.uid ]}
            ${toGuest apps [ config.users.users.exportarr.uid ]}
            ct state new oifname "${net.tap}" meta skuid != { ${
              lib.concatMapStringsSep ", " toString (
                [ 0 ] ++ lib.optional config.services.caddy.enable config.users.users.caddy.uid
              )
            } } reject
          }
        '';
      };

      systemd.timers = lib.genAttrs (map (name: "seerr-${name}") seerrApps) (unit: {
        wantedBy = [ "timers.target" ];
        timerConfig.OnActiveSec = "1min";
        restartTriggers = [ config.systemd.units."${unit}.service".unit ];
      });
      systemd.services = lib.mkMerge [
        (lib.genAttrs (map (name: "prometheus-exportarr-${name}-exporter") apps) (_: {
          serviceConfig.DynamicUser = false;
        }))
        (lib.genAttrs (map (name: "seerr-${name}") seerrApps) (unit: {
          wantedBy = lib.mkForce [ ];
          restartIfChanged = false;
          startLimitIntervalSec = 3600;
          startLimitBurst = 15;
          serviceConfig = {
            ExecStartPre = lib.getExe (awaitProfile (lib.removePrefix "seerr-" unit));
            RemainAfterExit = lib.mkForce false;
            Restart = "on-failure";
            RestartSec = "30s";
          };
        }))
        {
          seerr.unitConfig.RequiresMountsFor = [ config.nixflix.stateDir ];
          "microvm-virtiofsd@downloads" = {
            unitConfig.RequiresMountsFor = [ hostDumps ];
            serviceConfig.ExecStartPre = map (
              name: "${install} -D -m 0400 ${secret name} ${hostSecrets}/${name}"
            ) guestHeld;
          };
          arr-dumps-fresh = {
            description = "Fail when the downloads guest's database dumps are older than two days";
            startAt = "daily";
            path = [ pkgs.findutils ];
            enableStrictShellChecks = true;
            serviceConfig.Type = "oneshot";
            script = ''
              [ -e ${handover}/done ] || exit 0
              for db in ${lib.concatStringsSep " " apps}; do
                [ -e ${hostDumps}/"$db.sql.gz" ] || [ -e ${hostDumps}/"$db.prev.sql.gz" ] || continue
                if [ -z "$(find ${hostDumps}/"$db.sql.gz" ${hostDumps}/"$db.prev.sql.gz" -mtime -2 2> /dev/null)" ]; then
                  echo "$db has no dump newer than two days in ${hostDumps}" >&2
                  exit 1
                fi
              done
            '';
          };
          arr-handover = {
            description = "Dump the arr databases bastion still holds for the downloads guest to load";
            requiredBy = [ "microvm-virtiofsd@downloads.service" ];
            before = [ "microvm-virtiofsd@downloads.service" ];
            wants = [ "postgresql.target" ];
            after = [ "postgresql.target" ];
            unitConfig.RequiresMountsFor = [ (dirOf hostDumps) ];
            path = [
              config.services.postgresql.package
              pkgs.gzip
            ];
            enableStrictShellChecks = true;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              User = "postgres";
              ExecStartPre = "+${install} -d -o postgres -m 0700 ${hostDumps} ${handover}";
            };
            script = ''
              set -o pipefail
              [ ! -e ${handover}/done ] || exit 0
              for db in ${lib.concatStringsSep " " apps}; do
                exists=$(psql -Atc "select count(*) from pg_database where datname = '$db'")
                [ "$exists" = 1 ] || continue
                pg_dump --no-owner --no-privileges "$db" | gzip > ${handover}/"$db.sql.gz"
                mv -T ${handover}/"$db.sql.gz" ${hostDumps}/"$db.sql.gz"
              done
              touch ${handover}/done
            '';
          };
        }
      ];
    };
in
{
  flake.modules.nixos.arr = host;
}
