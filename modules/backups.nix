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
      ];
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
      recorded = lib.attrNames jobs ++ [ "drill-usb" ];
      dumps = config.services.postgresqlBackup;
      dumpDir = dumps.location;
      databases = config.services.postgresql.ensureDatabases;
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
      imports = [
        {
          options.fleet.databaseDumps = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "PostgreSQL dumps under `/srv`, as paths without `.sql.gz`, that the monthly restore drill reads back from the USB backup.";
          };
        }
      ];
      fleet.databaseDumps = map (db: "${dumpDir}/${db}") databases;
      sops.secrets = {
        backups-restic-password.key = "backups/restic-password";
        backups-rclone-pcloud.key = "backups/rclone-pcloud";
      };
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
              unitConfig.RequiresMountsFor = jobs.usb.mounts;
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
                for dump in ${lib.escapeShellArgs (map (inSnapshot "usb" "/srv") config.fleet.databaseDumps)}; do
                  if ! ${restic} ls latest "$dump.sql.gz" 2> /dev/null | grep -cxF "$dump.sql.gz" > /dev/null; then
                    echo "The latest snapshot has no fresh $dump.sql.gz; testing the previous one."
                    dump=$dump.prev
                  fi
                  ${restic} dump latest "$dump.sql.gz" | gzip -dc | tail -n 20 | grep -q 'PostgreSQL database dump complete'
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
          (lib.genAttrs (map (db: "postgresqlBackup-${db}") databases) (_: {
            unitConfig.RequiresMountsFor = [
              "/srv"
              config.services.postgresql.dataDir
            ];
          }))
        ];
        timers.restic-drill-usb.timerConfig = {
          RandomizedDelaySec = "2h";
          Persistent = true;
        };
      };

      preservation.preserveAt."/persist".directories =
        map
          (directory: {
            inherit directory;
            mode = "0700";
          })
          (
            map (name: "/var/cache/restic-backups-${name}") (lib.attrNames jobs)
            ++ [ "/var/cache/restic-drill-usb" ]
          );
    };
}
