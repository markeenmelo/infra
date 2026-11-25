{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) nixflix postgresql;
  inherit (config.fleet) domain;
  secretDir = "/run/arr-secrets";
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
    "YTS"
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

  namespaced =
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
      secret = name: { _secret = "${secretDir}/${name}"; };
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
      vpnNamespaces.${config.nixflix.vpn.namespace}.piaRegion = "ca";
      fleet.piaCredentials = lib.genAttrs [ "username" "password" ] (field: "${secretDir}/pia-${field}");
      nixflix = lib.mkMerge [
        {
          postgres.enable = true;
          vpn = {
            enable = true;
            wgConfFile = "/run/pia-${vpn}/wg.conf";
            allowedIngress = [ ];
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
                inet_exposure = 4;
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
      # the uid bastion allocated to qbittorrent, which owns its state; nixflix forces the whole account, so it is restated
      users.users.qbittorrent = lib.mkOverride 49 {
        uid = 994;
        isSystemUser = true;
        inherit (config.services.qbittorrent) group;
      };
      systemd.services = lib.mkMerge [
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
                map (name: "${name}:${secretDir}/${name}") (
                  map (name: "${name}-api-key") (decluttarrApps ++ [ "sabnzbd" ])
                )
                ++ [ "QBITTORRENT_PASSWORD:${secretDir}/qbittorrent-password" ];
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
              LoadCredential = map (name: "${name}:${secretDir}/${name}") [
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
              "webui-password-hash:${secretDir}/qbittorrent-password-hash"
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
            description = "Keep PIA's forwarded port open for qBittorrent";
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
              pkgs.jq
            ];
            enableStrictShellChecks = true;
            serviceConfig = {
              Restart = "on-failure";
              RestartSec = "30s";
              RestartSteps = 6;
              RestartMaxDelaySec = "30min";
              NotifyAccess = "all";
              RuntimeDirectory = "qbittorrent-port-forward";
              RuntimeDirectoryMode = "0700";
              UMask = "0077";
              LoadCredential = [
                "password:${secretDir}/qbittorrent-password"
                "pia-username:${secretDir}/pia-username"
                "pia-password:${secretDir}/pia-password"
              ];
            };
            script = ''
              api=http://${namespaceAddress}:${toString webuiPort}/api/v2
              server=${dirOf config.vpnNamespaces.${vpn}.wireguardConfigFile}/server.json
              cd "$RUNTIME_DIRECTORY"
              cn=$(jq -r .cn "$server")
              tunnel() { ip netns exec ${vpn} curl -fsS --retry 3 --max-time 30 "$@"; }
              pf() { tunnel -G --connect-to "$cn::$(jq -r .gateway "$server"):" --cacert ${./pia.crt} "$@"; }
              fw() { ip netns exec ${vpn} iptables "$@"; }
              tunnel --form "username=<$CREDENTIALS_DIRECTORY/pia-username" --form "password=<$CREDENTIALS_DIRECTORY/pia-password" \
                https://www.privateinternetaccess.com/api/client/v2/token | jq -je .token > token
              pf --data-urlencode token@token "https://$cn:19999/getSignature" > signature.json
              jq -e '.status == "OK"' signature.json > /dev/null
              jq -j .payload signature.json > payload
              jq -j .signature signature.json > signature
              port=$(base64 -d payload | jq -er .port)
              bind() { pf --data-urlencode payload@payload --data-urlencode signature@signature "https://$cn:19999/bindPort" | jq -e '.status == "OK"' > /dev/null; }
              bind
              fw -N qbittorrent-port 2>/dev/null || true
              fw -C INPUT -j qbittorrent-port 2>/dev/null || fw -I INPUT -j qbittorrent-port
              fw -F qbittorrent-port
              for proto in tcp udp; do
                fw -A qbittorrent-port -i ${vpn}0 -p "$proto" --dport "$port" -j ACCEPT
              done
              curl -fsS --retry 10 --retry-connrefused -c cookies --data-urlencode username=marcos \
                --data-urlencode "password@$CREDENTIALS_DIRECTORY/password" "$api/auth/login" > /dev/null
              curl -fsS -b cookies --data "json={\"listen_port\":$port,\"random_port\":false}" "$api/app/setPreferences"
              curl -fsS -b cookies --data hashes=all "$api/torrents/reannounce"
              echo "Forwarded port $port"
              systemd-notify RESTART_RESET=1
              while sleep 900; do
                bind
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
      options,
      pkgs,
      ...
    }:
    let
      vpn = config.nixflix.vpn.namespace;
      inherit (config.vpnNamespaces.${vpn}) namespaceAddress;
      appPort = name: config.nixflix.${name}.config.hostConfig.port;
      secret = name: config.sops.secrets."arr-${name}".path;
      arrUnits = apps ++ [
        "qbittorrent"
        "qbittorrent-port-forward"
        "sabnzbd"
        "decluttarr"
        "easynews-indexer"
      ];
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
      appHeld = [
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
      ];
      guestDumps = "${dirOf config.services.postgresqlBackup.location}/downloads";
      returned = "${guestDumps}-handover/returned";
      guestUnits = [
        "microvm@downloads.service"
        "microvm-virtiofsd@downloads.service"
      ];
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
                http://${namespaceAddress}:${toString (appPort name)}/api/v3/qualityprofile |
                jq -e --arg profile ${lib.escapeShellArg storageProfile} 'any(.[]; .name == $profile)' > /dev/null; then
                exit 0
              fi
              sleep 5
            done
            echo "${name} has no profile ${storageProfile} after 3 minutes" >&2
            exit 1
          '';
        };
      toApps =
        names: uid:
        ''ct state new oifname "${vpn}-br" meta skuid ${toString uid} tcp dport { ${
          lib.concatMapStringsSep ", " (name: toString (appPort name)) names
        } } accept'';
    in
    {
      imports = [
        namespaced
        postgresql
      ];

      sops.secrets = lib.listToAttrs (
        map (
          name:
          lib.nameValuePair "arr-${name}" {
            key = "arr/${name}";
            path = lib.mkIf (lib.elem name appHeld) "${secretDir}/${name}";
            restartUnits =
              map (unit: "${unit}.service") (
                hostUnits.${name} or [ ] ++ lib.optionals (lib.elem name appHeld) arrUnits
              )
              ++ map (app: "seerr-${app}.timer") (lib.filter (app: name == "${app}-api-key") seerrApps);
          }
        ) (lib.unique (lib.attrNames hostUnits ++ appHeld))
        ++
          map
            (
              field:
              lib.nameValuePair "pia-${field}" {
                key = "pia/${field}";
                path = "${secretDir}/pia-${field}";
                restartUnits = [ "${vpn}.service" ];
              }
            )
            [
              "username"
              "password"
            ]
      );

      nixflix.seerr = lib.mkMerge [
        {
          enable = true;
          vpn.enable = false;
          apiKey._secret = secret "seerr-api-key";
        }
        (lib.genAttrs seerrApps (
          name:
          lib.mkMerge [
            options.nixflix.seerr.${name}.default
            {
              ${lib.head (lib.attrNames options.nixflix.seerr.${name}.default)}.activeProfileName =
                storageProfile;
            }
          ]
        ))
      ];

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
            url = "http://${namespaceAddress}:${toString (appPort name)}";
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
          address = namespaceAddress;
        }))
        {
          qbittorrent = {
            port = config.services.qbittorrent.webuiPort;
            address = namespaceAddress;
          };
          sabnzbd = {
            inherit (config.nixflix.usenetClients.sabnzbd.settings.misc) port;
            address = namespaceAddress;
          };
          seerr = { inherit (config.nixflix.seerr) port; };
        }
      ];
      nixpkgs.config.allowUnfreePackages = [ "unrar" ];
      networking.nftables.tables.arr = {
        family = "inet";
        content = ''
          chain forward {
            type filter hook forward priority -200; policy accept;
            oifname "${vpn}-br" drop
            iifname "${vpn}-br" drop
          }
          chain input {
            type filter hook input priority -200; policy accept;
            iifname "${vpn}-br" ct state new drop
          }
          chain output {
            type filter hook output priority -150; policy accept;
            ${toApps seerrApps config.users.users.${config.nixflix.seerr.user}.uid}
            ${toApps apps config.users.users.exportarr.uid}
            ct state new oifname "${vpn}-br" meta skuid != { ${
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
          # shortcut: migration from the downloads guest that can replace these databases, delete it once no kept generation runs that guest
          arr-return = {
            description = "Replace the arr databases with the downloads guest's dumps when they are newer than the last return";
            requiredBy = map (name: "${name}.service") arrUnits;
            before = map (name: "${name}.service") arrUnits;
            requires = [ "postgresql-ready.target" ];
            after = [ "postgresql-ready.target" ] ++ guestUnits;
            conflicts = guestUnits;
            unitConfig.RequiresMountsFor = [ guestDumps ];
            path = [
              config.services.postgresql.package
              pkgs.findutils
              pkgs.gawk
              pkgs.gzip
              pkgs.util-linux
            ];
            enableStrictShellChecks = true;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              PrivateNetwork = true;
              RestrictAddressFamilies = [ "AF_UNIX" ];
              ProtectSystem = "strict";
              ReadWritePaths = [
                "/run/postgresql"
                (dirOf returned)
              ];
              ProtectHome = true;
              PrivateTmp = true;
              PrivateDevices = true;
              NoNewPrivileges = true;
              CapabilityBoundingSet = [
                "CAP_SETUID"
                "CAP_SETGID"
                "CAP_DAC_OVERRIDE"
              ];
              SystemCallFilter = [ "@system-service" ];
              ExecStartPre = "+${lib.getExe' pkgs.coreutils "install"} -d -o postgres -m 0700 ${dirOf returned}";
            };
            script = ''
              set -o pipefail
              if [ -e ${returned} ]; then
                [ -n "$(find ${guestDumps} -maxdepth 1 -name '*.sql.gz' -newer ${returned} 2> /dev/null)" ] || exit 0
              elif [ ! -e ${dirOf returned}/done ]; then
                exit 0
              fi
              key=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
              for db in ${lib.concatStringsSep " " apps}; do
                dump=${guestDumps}/$db.sql.gz
                [ -f "$dump" ] && [ ! -L "$dump" ] || dump=${guestDumps}/$db.prev.sql.gz
                if [ ! -f "$dump" ] || [ -L "$dump" ]; then
                  echo "$db has no dump in ${guestDumps}; not replacing any database" >&2
                  exit 1
                fi
                if [ -z "$(find "$dump" -mtime -2)" ]; then
                  echo "$dump is older than two days; not replacing any database" >&2
                  exit 1
                fi
                echo "Loading $dump into $db-return"
                runuser -u postgres -- dropdb --if-exists --force "$db-return"
                runuser -u postgres -- createdb -O "$db" "$db-return"
                {
                  printf '\\restrict %s\n' "$key"
                  gunzip -c "$dump" | awk 'NR <= 10 && !k && /^\\restrict [A-Za-z0-9]+$/ { k = $2; next } k && $0 == "\\unrestrict " k { next } { print }'
                  printf '\\unrestrict %s\n' "$key"
                } | runuser -u "$db" -- psql -v ON_ERROR_STOP=1 --single-transaction -d "$db-return" > /dev/null
              done
              for db in ${lib.concatStringsSep " " apps}; do
                echo "Replacing $db"
                runuser -u postgres -- dropdb --if-exists --force "$db"
                runuser -u postgres -- psql -v ON_ERROR_STOP=1 -c "alter database \"$db-return\" rename to \"$db\""
              done
              touch ${returned}
            '';
          };
        }
      ];
    };
in
{
  flake.modules.nixos.arr = host;
}
