{ config, ... }:
let
  inherit (config.fleet) hosts;
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
        "/srv/backup-thinkpad"
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
      thinkpad = {
        repo = "/srv/backup-thinkpad";
        port = 8010;
        listen = hosts.${config.networking.hostName}.tailnetAddress;
        # shortcut: the ThinkPad's tailnet address is a literal, read it from fleet facts when the thinkpad host lands
        client = "100.119.79.113";
      };
      restic = lib.getExe pkgs.restic;
    in
    {
      sops.secrets =
        lib.genAttrs
          [
            "backups-restic-password"
            "backups-thinkpad-password"
            "backups-rclone-pcloud"
          ]
          (name: {
            sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
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
              path = [ pkgs.gzip ];
              script = ''
                set -o pipefail
                ${restic} check --retry-lock 30m --read-data-subset="$(date +%-m)/12"
                for db in ${lib.escapeShellArgs databases}; do
                  dump=${inSnapshot "usb" "/srv" "${dumpDir}/$db"}
                  if ! ${restic} ls latest "$dump.sql.gz" > /dev/null 2>&1; then
                    echo "The latest snapshot has no fresh dump of $db; testing the previous one."
                    dump=$dump.prev
                  fi
                  ${restic} dump latest "$dump.sql.gz" | gzip -t
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
            backup-thinkpad = {
              description = "Append-only restic server for the ThinkPad's home backups";
              after = [ "tailscaled.service" ];
              wantedBy = [ "multi-user.target" ];
              unitConfig.RequiresMountsFor = [ thinkpad.repo ];
              serviceConfig = {
                User = "backup-thinkpad";
                Group = "backup-thinkpad";
                ExecStart = "${lib.getExe pkgs.rclone} serve restic --append-only --addr ${thinkpad.listen}:${toString thinkpad.port} ${thinkpad.repo}";
                Restart = "on-failure";
                RestartSec = "10s";
                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [ thinkpad.repo ];
                NoNewPrivileges = true;
                PrivateTmp = true;
              };
            };
            backup-thinkpad-retention = {
              description = "Prune and check the ThinkPad's backups unless a snapshot carries a forged date";
              conflicts = [ "backup-thinkpad.service" ];
              after = [ "backup-thinkpad.service" ];
              unitConfig.RequiresMountsFor = [ thinkpad.repo ];
              startAt = "Sun 05:00";
              enableStrictShellChecks = true;
              path = [
                pkgs.jq
                pkgs.coreutils
              ];
              environment = {
                RESTIC_REPOSITORY = thinkpad.repo;
                RESTIC_PASSWORD_FILE = "%d/password";
              };
              serviceConfig = {
                Type = "oneshot";
                User = "backup-thinkpad";
                Group = "backup-thinkpad";
                LoadCredential = [ "password:${config.sops.secrets.backups-thinkpad-password.path}" ];
                CacheDirectory = "backup-thinkpad";
                Environment = "RESTIC_CACHE_DIR=%C/backup-thinkpad";
                ExecStopPost = "+${pkgs.systemd}/bin/systemctl start --no-block backup-thinkpad.service";
                ProtectSystem = "strict";
                ProtectHome = true;
                ReadWritePaths = [ thinkpad.repo ];
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
        timers.backup-thinkpad-retention.timerConfig.Persistent = true;
        tmpfiles.rules = [ "d ${thinkpad.repo} 0700 backup-thinkpad backup-thinkpad -" ];
      };

      # the uid that owns the ThinkPad's repository, allocated by the old generation
      users.users.backup-thinkpad = {
        isSystemUser = true;
        uid = 355;
        group = "backup-thinkpad";
      };
      users.groups.backup-thinkpad.gid = 355;

      networking.firewall.extraInputRules = ''
        iifname "${config.services.tailscale.interfaceName}" ip saddr ${thinkpad.client} tcp dport ${toString thinkpad.port} accept
      '';
      networking.nftables.enable = true;
      networking.nftables.tables.backup-thinkpad = {
        family = "inet";
        content = ''
          chain output {
            type filter hook output priority -150; policy accept;
            oifname "lo" ip daddr ${thinkpad.listen} tcp dport ${toString thinkpad.port} reject
          }
        '';
      };
    };
}
