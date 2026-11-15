{ config, lib, ... }:
let
  inherit (config.fleet) hosts;
  laptops = lib.filterAttrs (_: host: host.homeBackup != null) hosts;
in
{
  flake.modules.nixos.backups =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      repo = jobs.usb.repository;
      jobs = {
        usb = {
          repository = "/mnt/backup/restic";
          at = "02:30";
          mounts = [ "/mnt/backup" ];
          rcloneConfigFile = null;
          checkOpts = [ ];
        };
        pcloud = {
          repository = "rclone:pcloud:bastion/restic";
          at = "04:00";
          mounts = [ ];
          rcloneConfigFile = config.sops.secrets.backups-rclone-pcloud.path;
          checkOpts = [ "--read-data-subset=1%" ];
        };
      };
      snapOf = name: "restic-${name}";
      roots = [
        "/srv"
        "/srv/immich"
        "/srv/opencloud"
        "/srv/nixflix-state"
      ]
      ++ map laptopRepo (lib.attrNames laptops);
      laptopRepo = name: "/srv/backup-${name}";
      perLaptop = f: lib.mkMerge (lib.mapAttrsToList f laptops);
      listen = hosts.${config.networking.hostName}.tailnetAddress;
      datasets = map (root: config.fileSystems.${root}.device) roots;
      inSnapshot =
        name: root: path:
        "${root}/.zfs/snapshot/${snapOf name}${lib.removePrefix root path}";
      success =
        name:
        pkgs.writeShellScript "restic-${name}-success" ''
          printf 'restic_last_success_timestamp_seconds{backup="${name}"} %s\n' "$(${lib.getExe' pkgs.coreutils "date"} +%s)" \
            > ${config.fleet.metricsDir}/restic-${name}.prom.tmp
          ${lib.getExe' pkgs.coreutils "mv"} ${config.fleet.metricsDir}/restic-${name}.prom.tmp ${config.fleet.metricsDir}/restic-${name}.prom
        '';
      recorded = lib.attrNames jobs ++ [ "drill-usb" ] ++ lib.attrNames laptops;
      dumps = config.services.postgresqlBackup;
      dumpDir = dumps.location;
      databases = lib.filter (db: !lib.hasSuffix "-logs" db) config.services.postgresql.ensureDatabases;
      persisted =
        name:
        map (path: "/persist/.${snapOf name}${path}") [
          "/var/log"
          "/var/cache"
          "/etc/ssh"
          "/etc/machine-id"
          "/var/lib/sbctl"
          "/var/lib/systemd/random-seed"
          "/var/lib/tailscale*"
          "/var/lib/prometheus2"
          "/var/lib/loki"
          "/zfs"
          "/home/*/.ssh"
          "/home/*/.config/sops"
          "/home/*/.cache"
        ];
      release = name: ''
        for dataset in ${lib.escapeShellArgs datasets}; do
          zfs destroy "$dataset@${snapOf name}" 2>/dev/null || true
        done
        if [ -d /persist/.${snapOf name} ]; then btrfs subvolume delete /persist/.${snapOf name}; fi
      '';
      restic = lib.getExe pkgs.restic;
    in
    {
      sops.secrets =
        lib.genAttrs
          (
            [
              "backups-restic-password"
              "backups-rclone-pcloud"
            ]
            ++ map (name: "backups-${name}-password") (lib.attrNames laptops)
          )
          (name: {
            key = lib.replaceStrings [ "backups-" ] [ "backups/" ] name;
          });
      assertions =
        map
          (path: {
            assertion = lib.any (root: path == root || lib.hasPrefix "${root}/" path) (lib.tail roots);
            message = "${path} holds household data but is outside every backup root.";
          })
          [
            config.services.immich.mediaLocation
            config.services.opencloud.stateDir
          ];

      services.postgresqlBackup = {
        enable = true;
        inherit databases;
        location = "/srv/backups/postgresql";
        startAt = [ ];
        pgdumpOptions = "--no-owner --no-privileges --lock-wait-timeout=5min";
      };

      services.restic.backups = lib.mapAttrs (name: job: {
        inherit (job) repository rcloneConfigFile checkOpts;
        passwordFile = config.sops.secrets.backups-restic-password.path;
        timerConfig = {
          OnCalendar = job.at;
          Persistent = true;
        };
        paths = [ "/persist/.${snapOf name}" ] ++ map (root: inSnapshot name root root) roots;
        exclude = [
          (inSnapshot name "/srv/immich" "/srv/immich/library/thumbs")
          (inSnapshot name "/srv/immich" "/srv/immich/library/encoded-video")
        ]
        ++ persisted name;
        extraBackupArgs = [ "--retry-lock 30m" ];
        pruneOpts = [
          "--retry-lock 30m"
          "--group-by host"
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
        backupPrepareCommand = ''
          set -euo pipefail
          ${release name}
          for db in ${lib.escapeShellArgs databases}; do
            systemctl start "postgresqlBackup-$db.service" || echo "Dump of $db failed; backing up the last good one."
          done
          for dataset in ${lib.escapeShellArgs datasets}; do
            zfs snapshot "$dataset@${snapOf name}"
          done
          btrfs subvolume snapshot -r /persist /persist/.${snapOf name}
        '';
        backupCleanupCommand = release name;
      }) jobs;

      systemd = {
        services = lib.mkMerge [
          (lib.mapAttrs' (
            name: job:
            lib.nameValuePair "restic-backups-${name}" {
              path = [
                config.boot.zfs.package
                pkgs.btrfs-progs
              ];
              unitConfig.RequiresMountsFor = roots ++ job.mounts;
              serviceConfig = {
                PrivateNetwork = job.rcloneConfigFile == null;
                ExecStartPost = success name;
              };
            }
          ) jobs)
          {
            restic-backups-pcloud.after = [ "restic-backups-usb.service" ];
            restic-drill-usb = {
              description = "Read a twelfth of the USB backup and test the latest database dumps";
              after = [ "restic-backups-usb.service" ];
              unitConfig.RequiresMountsFor = [ "/mnt/backup" ];
              startAt = "*-*-15 12:00";
              enableStrictShellChecks = true;
              environment = {
                RESTIC_REPOSITORY = repo;
                RESTIC_PASSWORD_FILE = config.sops.secrets.backups-restic-password.path;
              };
              serviceConfig = {
                Type = "oneshot";
                PrivateNetwork = true;
                ExecStartPost = success "drill-usb";
                CacheDirectory = "restic-drill-usb";
                Environment = "RESTIC_CACHE_DIR=%C/restic-drill-usb";
                TimeoutStartSec = "12h";
              };
              path = [
                pkgs.gzip
                pkgs.gnugrep
              ];
              script = ''
                set -o pipefail
                ${restic} check --retry-lock 30m --read-data-subset="$(date +%-m)/12"
                for db in ${lib.escapeShellArgs databases}; do
                  dump=${inSnapshot "usb" "/srv" "${dumpDir}/$db"}
                  if ! ${restic} ls latest "$dump.sql.gz" 2> /dev/null | grep -cxF "$dump.sql.gz" > /dev/null; then
                    echo "The latest snapshot has no fresh dump of $db; testing the previous one."
                    dump=$dump.prev
                  fi
                  ${restic} dump latest "$dump.sql.gz" | gzip -dc | tail -n 5 | grep -q 'PostgreSQL database dump complete'
                done
              '';
            };
            restic-success-seed = {
              description = "Start each restic job's success clock and drop those of removed jobs";
              wantedBy = [ "multi-user.target" ];
              after = [ "systemd-tmpfiles-setup.service" ];
              unitConfig.RequiresMountsFor = [ config.fleet.metricsDir ];
              restartTriggers = [ (lib.concatStringsSep " " recorded) ];
              enableStrictShellChecks = true;
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                cd ${config.fleet.metricsDir}
                for file in restic-*.prom; do
                  [ -e "$file" ] || continue
                  case "$file" in
                    ${lib.concatMapStringsSep "|" (name: "restic-${name}.prom") recorded}) ;;
                    *) rm -- "$file" ;;
                  esac
                done
                for name in ${lib.escapeShellArgs recorded}; do
                  [ -e "restic-$name.prom" ] ||
                    printf 'restic_last_success_timestamp_seconds{backup="%s"} %s\n' "$name" "$(date +%s)" > "restic-$name.prom"
                done
              '';
            };
          }
          (perLaptop (
            name: laptop:
            let
              repo = laptopRepo name;
              account = "backup-${name}";
            in
            {
              ${account} = {
                description = "Append-only restic server for ${name}'s home backups";
                after = [ "tailscaled.service" ];
                wantedBy = [ "multi-user.target" ];
                unitConfig.RequiresMountsFor = [ repo ];
                serviceConfig = {
                  User = account;
                  Group = account;
                  ExecStartPre = "+${lib.getExe' pkgs.coreutils "install"} -d -o ${account} -g ${account} -m 0700 ${repo}";
                  ExecStart = "${lib.getExe pkgs.rclone} serve restic --append-only --addr ${listen}:${toString laptop.homeBackup.port} ${repo}";
                  Restart = "on-failure";
                  RestartSec = "10s";
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  ReadWritePaths = [ repo ];
                  NoNewPrivileges = true;
                  PrivateTmp = true;
                };
              };
              "${account}-freshness" = {
                description = "Record when ${name} last uploaded a snapshot";
                startAt = "hourly";
                unitConfig.RequiresMountsFor = [
                  repo
                  config.fleet.metricsDir
                ];
                enableStrictShellChecks = true;
                path = [
                  pkgs.coreutils
                  pkgs.findutils
                ];
                serviceConfig = {
                  Type = "oneshot";
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  ReadWritePaths = [ config.fleet.metricsDir ];
                };
                script = ''
                  newest=$(find ${repo}/snapshots -type f -printf '%T@\n' 2> /dev/null | sort -n | tail -n 1 || true)
                  [ -n "$newest" ] || exit 0
                  printf 'restic_last_success_timestamp_seconds{backup="${name}"} %s\n' "''${newest%.*}" \
                    > ${config.fleet.metricsDir}/restic-${name}.prom.tmp
                  mv ${config.fleet.metricsDir}/restic-${name}.prom.tmp ${config.fleet.metricsDir}/restic-${name}.prom
                '';
              };
              "${account}-retention" = {
                description = "Prune and check ${name}'s backups unless a snapshot carries a forged date";
                conflicts = [ "${account}.service" ];
                after = [ "${account}.service" ];
                unitConfig.RequiresMountsFor = [ repo ];
                startAt = "Sun 05:00";
                enableStrictShellChecks = true;
                path = [
                  pkgs.jq
                  pkgs.coreutils
                ];
                environment = {
                  RESTIC_REPOSITORY = repo;
                  RESTIC_PASSWORD_FILE = "%d/password";
                };
                serviceConfig = {
                  Type = "oneshot";
                  User = account;
                  Group = account;
                  LoadCredential = [ "password:${config.sops.secrets."backups-${name}-password".path}" ];
                  CacheDirectory = account;
                  Environment = "RESTIC_CACHE_DIR=%C/${account}";
                  ExecStopPost = "+${pkgs.systemd}/bin/systemctl start --no-block ${account}.service";
                  ProtectSystem = "strict";
                  ProtectHome = true;
                  ReadWritePaths = [ repo ];
                };
                script = ''
                  set -o pipefail
                  now=$(date +%s)
                  ${restic} snapshots --json --retry-lock 30m | jq -r '.[] | "\(.id) \(.time)"' |
                    while read -r id time; do
                      claimed=$(date -d "$time" +%s)
                      uploaded=$(stat -c %Y "$RESTIC_REPOSITORY/snapshots/$id")
                      if [ "$claimed" -gt $((now + 3600)) ] || [ "$uploaded" -gt $((claimed + 8 * 86400)) ]; then
                        echo "Snapshot $id claims $time but was uploaded $(date -d "@$uploaded"); not pruning."
                        exit 1
                      fi
                    done
                  ${restic} forget --prune --retry-lock 30m --keep-within 14d --keep-daily 7 --keep-weekly 5 --keep-monthly 12
                  ${restic} check --retry-lock 30m --read-data-subset=5%
                '';
              };
            }
          ))
          (lib.genAttrs (map (db: "postgresqlBackup-${db}") databases) (_: {
            unitConfig.RequiresMountsFor = [
              "/srv"
              config.services.postgresql.dataDir
            ];
          }))
        ];
        timers = lib.mkMerge [
          {
            restic-drill-usb.timerConfig = {
              RandomizedDelaySec = "2h";
              Persistent = true;
            };
          }
          (perLaptop (name: _: { "backup-${name}-retention".timerConfig.Persistent = true; }))
        ];
      };

      users = perLaptop (
        name: laptop: {
          users."backup-${name}" = {
            isSystemUser = true;
            inherit (laptop.homeBackup) uid;
            group = "backup-${name}";
          };
          groups."backup-${name}".gid = laptop.homeBackup.uid;
        }
      );
      preservation.preserveAt."/persist".directories =
        map
          (directory: {
            inherit directory;
            mode = "0700";
          })
          (
            map (name: "/var/cache/restic-backups-${name}") (lib.attrNames jobs)
            ++ [ "/var/cache/restic-drill-usb" ]
          )
        ++ map (name: {
          directory = "/var/cache/backup-${name}";
          user = "backup-${name}";
          group = "backup-${name}";
          mode = "0700";
        }) (lib.attrNames laptops);

      networking.firewall.extraInputRules = lib.concatStrings (
        lib.mapAttrsToList (_: laptop: ''
          iifname "${config.services.tailscale.interfaceName}" ip saddr ${laptop.tailnetAddress} tcp dport ${toString laptop.homeBackup.port} accept
        '') laptops
      );
      fleet.loopbackGuards = perLaptop (
        name: laptop: {
          "backup-${name}" = {
            ports = [ laptop.homeBackup.port ];
            users = [ ];
          };
        }
      );
    };

  flake.modules.nixos.backup-home =
    { config, ... }:
    let
      host = config.networking.hostName;
      inherit (hosts.${host}.homeBackup) port;
      password = "backups-${host}-password";
      home = config.users.users.marcos.home;
    in
    {
      sops.secrets.${password}.key = "backups/${host}-password";
      services.restic.backups.home = {
        repository = "rest:http://${hosts.bastion.tailnetAddress}:${toString port}/";
        passwordFile = config.sops.secrets.${password}.path;
        initialize = true;
        paths = [ home ];
        exclude =
          map (path: "${home}/${path}") (
            import ./_home-secrets.nix
            ++ [
              ".cache"
              ".gvfs"
              ".local/share/Trash"
              ".local/share/Steam/steamapps/common"
              ".local/share/Steam/steamapps/shadercache"
              ".local/share/Steam/steamapps/downloading"
              ".local/share/Steam/steamapps/temp"
            ]
          )
          ++ [ "**/node_modules" ];
        extraBackupArgs = [ "--exclude-caches" ];
        timerConfig = {
          OnCalendar = "00/6:00";
          RandomizedDelaySec = "30m";
          Persistent = true;
        };
      };
      systemd.services.restic-backups-home = {
        wants = [ "tailscaled.service" ];
        after = [ "tailscaled.service" ];
        conflicts = [ "sleep.target" ];
        before = [ "sleep.target" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "1h";
        };
      };
      preservation.preserveAt."/persist".directories = [ "/var/cache/restic-backups-home" ];
      networking.nftables.enable = true;
      networking.nftables.tables.backup-home = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority -150; policy accept;
            ip daddr ${hosts.bastion.tailnetAddress} tcp dport ${toString port} meta skuid != 0 reject
          }
        '';
      };
    };
}
