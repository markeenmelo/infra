{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) nixflix postgresql;
  inherit (config.fleet) domain;
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
      name = "DrunkenSlug";
      baseUrl = "https://drunkenslug.com";
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
in
{
  flake.modules.nixos.arr =
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
      qbittorrent = config.nixflix.torrentClients.qbittorrent;
      inherit (config.services.qbittorrent) webuiPort;
      sabnzbd = config.nixflix.usenetClients.sabnzbd;
      secret = name: { _secret = config.sops.secrets."arr-${name}".path; };
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
        assert lib.all (part: lib.hasInfix part script) from;
        lib.mkForce (
          lib.replaceStrings from (
            [ ''echo "Response body omitted: it may echo API keys."'' ] ++ lib.attrValues rewrites
          ) script
        );
      decluttarrApps = [
        "sonarr"
        "radarr"
      ];
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
                  base_url = "http://${namespaceAddress}:${toString config.nixflix.${name}.config.hostConfig.port}";
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
      imports = [
        nixflix
        postgresql
      ];
      sops.secrets =
        lib.mapAttrs'
          (name: units: {
            name = "arr-${name}";
            value = {
              sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
              key = "arr/${name}";
              restartUnits = map (unit: "${unit}.service") units;
            };
          })
          {
            sonarr-api-key = [
              "sonarr"
              "prowlarr-applications"
              "seerr"
              "decluttarr"
            ];
            radarr-api-key = [
              "radarr"
              "prowlarr-applications"
              "seerr"
              "decluttarr"
            ];
            seerr-api-key = [ "seerr" ];
            prowlarr-api-key = [ "prowlarr" ];
            password = [
              "sonarr-config"
              "radarr-config"
              "prowlarr-config"
              "sabnzbd"
            ];
            sabnzbd-api-key = [
              "sabnzbd"
              "sonarr-downloadclients"
              "radarr-downloadclients"
              "decluttarr"
            ];
            sabnzbd-nzb-key = [ "sabnzbd" ];
            newshosting-username = [
              "sabnzbd"
              "easynews-indexer"
            ];
            newshosting-password = [ "sabnzbd" ];
            tweaknews-username = [ "sabnzbd" ];
            easynews-password = [ "easynews-indexer" ];
            easynews-api-key = [
              "easynews-indexer"
              "prowlarr-indexers"
            ];
            ninjacentral-api-key = [ "prowlarr-indexers" ];
            nzbgeek-api-key = [ "prowlarr-indexers" ];
            althub-api-key = [ "prowlarr-indexers" ];
            drunkenslug-api-key = [ "prowlarr-indexers" ];
            qbittorrent-password = [
              "sonarr-downloadclients"
              "radarr-downloadclients"
              "qbittorrent-port-forward"
              "decluttarr"
            ];
            qbittorrent-password-hash = [ "qbittorrent" ];
            proton-wireguard = [ vpn ];
          };
      nixflix = lib.mkMerge [
        {
          postgres.enable = true;
          vpn = {
            enable = true;
            wgConfFile = config.sops.secrets.arr-proton-wireguard.path;
            accessibleFrom = [ ];
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
          seerr = {
            enable = true;
            vpn.enable = false;
            apiKey = secret "seerr-api-key";
            sonarr = lib.mkMerge [
              options.nixflix.seerr.sonarr.default
              { Sonarr.activeProfileName = storageProfile; }
            ];
            radarr = lib.mkMerge [
              options.nixflix.seerr.radarr.default
              { Radarr.activeProfileName = storageProfile; }
            ];
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
            };
          };
        }))
      ];
      # the uid that owns qbittorrent's state, allocated by the old generation; nixflix pins 70 with mkForce
      users.users.qbittorrent.uid = lib.mkOverride 49 988;
      fleet.web.apps = lib.mkMerge [
        (lib.genAttrs apps (name: {
          inherit (config.nixflix.${name}.config.hostConfig) port;
          address = namespaceAddress;
          tailnetOnly = true;
        }))
        {
          qbittorrent = {
            port = webuiPort;
            address = namespaceAddress;
            tailnetOnly = true;
          };
          sabnzbd = {
            inherit (sabnzbd.settings.misc) port;
            address = namespaceAddress;
            tailnetOnly = true;
          };
          seerr = {
            inherit (config.nixflix.seerr) port;
            tailnetOnly = true;
          };
        }
      ];
      nixpkgs.config.allowUnfreePackages = [ "unrar" ];
      networking.nftables.tables.arr-vpn = {
        family = "inet";
        content = ''
          chain forward {
            type filter hook forward priority -200; policy accept;
            oifname "${vpn}-br" counter drop
            iifname "${vpn}-br" counter drop
          }
          chain output {
            type filter hook output priority -150; policy accept;
            ct state new oifname "${vpn}-br" meta skuid ${
              toString config.users.users.${config.nixflix.seerr.user}.uid
            } tcp dport { ${
              lib.concatMapStringsSep ", " (name: toString config.nixflix.${name}.config.hostConfig.port) [
                "sonarr"
                "radarr"
              ]
            } } accept
            ct state new oifname "${vpn}-br" meta skuid != { ${
              lib.concatMapStringsSep ", " toString (
                [ 0 ] ++ lib.optional config.services.caddy.enable config.users.users.caddy.uid
              )
            } } reject
          }
        '';
      };
      systemd.services = lib.mkMerge [
        (lib.genAttrs
          (
            apps
            ++ [
              "qbittorrent"
              "sabnzbd"
              "seerr"
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
              "exit \"$RC\"" = ''[ "$RC" -eq 0 ] || echo "Some indexers failed; the others were applied."'';
            };
          };
          prowlarr-applications.script = withoutResponseBody "applications" { };
          recyclarr.vpnConfinement = {
            enable = true;
            vpnNamespace = vpn;
          };
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
            vpnConfinement = {
              enable = true;
              vpnNamespace = vpn;
            };
            enableStrictShellChecks = true;
            serviceConfig = {
              DynamicUser = true;
              SupplementaryGroups = [ config.nixflix.globals.libraryOwner.group ];
              Restart = "on-failure";
              RestartSec = "30s";
              StateDirectory = "decluttarr";
              WorkingDirectory = "%S/decluttarr";
              LoadCredential =
                map (name: "${name}:${config.sops.secrets."arr-${name}".path}") (
                  map (name: "${name}-api-key") (decluttarrApps ++ [ "sabnzbd" ])
                )
                ++ [ "QBITTORRENT_PASSWORD:${config.sops.secrets.arr-qbittorrent-password.path}" ];
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
            vpnConfinement = {
              enable = true;
              vpnNamespace = vpn;
            };
            enableStrictShellChecks = true;
            serviceConfig = {
              DynamicUser = true;
              Restart = "on-failure";
              RestartSec = "5s";
              LoadCredential = map (name: "${name}:${config.sops.secrets."arr-${name}".path}") [
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
            LoadCredential = [
              "webui-password-hash:${config.sops.secrets.arr-qbittorrent-password-hash.path}"
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
            requires = [
              "${vpn}.service"
              "qbittorrent.service"
            ];
            wantedBy = [ "multi-user.target" ];
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
              LoadCredential = [ "password:${config.sops.secrets.arr-qbittorrent-password.path}" ];
            };
            script = ''
              api=http://${namespaceAddress}:${toString webuiPort}/api/v2
              cookies=$RUNTIME_DIRECTORY/cookies
              current=""
              fw() { ip netns exec ${vpn} iptables "$@"; }
              fw -N qbittorrent-port 2>/dev/null || true
              fw -C INPUT -j qbittorrent-port 2>/dev/null || fw -I INPUT -j qbittorrent-port
              open_port() {
                fw -F qbittorrent-port
                for proto in tcp udp; do
                  fw -A qbittorrent-port -i ${vpn}0 -p "$proto" --dport "$1" -j ACCEPT
                done
              }
              set_port() {
                curl -fsS -c "$cookies" --data-urlencode username=marcos \
                  --data-urlencode "password@$CREDENTIALS_DIRECTORY/password" "$api/auth/login" > /dev/null
                curl -fsS -b "$cookies" --data "json={\"listen_port\":$1,\"random_port\":false}" "$api/app/setPreferences"
                curl -fsS -b "$cookies" --data hashes=all "$api/torrents/reannounce"
              }
              while true; do
                port=$(ip netns exec ${vpn} natpmpc -a 1 0 udp 60 -g ${protonGateway} | awk '/Mapped public port/ { print $4 }')
                ip netns exec ${vpn} natpmpc -a 1 0 tcp 60 -g ${protonGateway} > /dev/null
                if [ -z "$port" ]; then
                  echo "No port from ${protonGateway}; is the tunnel up?"
                  sleep 5
                  continue
                fi
                if [ "$port" != "$current" ]; then
                  echo "Forwarded port $current -> $port"
                  open_port "$port" && set_port "$port" && current=$port
                fi
                sleep 45
              done
            '';
          };
        }
      ];
    };
}
