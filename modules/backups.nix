{
  flake.modules.nixos.backups =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      repo = "/mnt/backup/restic";
      name = "usb";
      snap = "restic-${name}";
      roots = [
        "/srv"
        "/srv/immich"
        "/srv/opencloud"
        "/srv/nixflix-state"
        "/srv/backup-thinkpad"
      ];
      datasets = map (root: config.fileSystems.${root}.device) roots;
      inSnapshot = root: path: "${root}/.zfs/snapshot/${snap}${lib.removePrefix root path}";
      dumps = config.services.postgresqlBackup;
      dumpDir = dumps.location;
      databases = lib.filter (db: !lib.hasSuffix "-logs" db) config.services.postgresql.ensureDatabases;
      persisted = map (path: "/persist/.${snap}${path}") [
        "/var/log"
        "/var/cache"
        "/etc/ssh"
        "/etc/machine-id"
        "/var/lib/sbctl"
        "/var/lib/systemd/random-seed"
        "/var/lib/tailscale"
        "/zfs"
        "/home/*/.ssh"
        "/home/*/.config/sops"
        "/home/*/.cache"
      ];
      release = ''
        for dataset in ${lib.escapeShellArgs datasets}; do
          zfs destroy "$dataset@${snap}" 2>/dev/null || true
        done
        if [ -d /persist/.${snap} ]; then btrfs subvolume delete /persist/.${snap}; fi
      '';
      thinkpad = {
        repo = "/srv/backup-thinkpad";
        port = 8010;
        # bastion's and the ThinkPad's tailnet addresses, from opentofu/tailscale/main.tf
        listen = "100.105.158.109";
        client = "100.119.79.113";
      };
      restic = lib.getExe pkgs.restic;
    in
    {
      sops.secrets = lib.genAttrs [ "backups-restic-password" "backups-thinkpad-password" ] (name: {
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

      services.restic.backups.${name} = {
        repository = repo;
        passwordFile = config.sops.secrets.backups-restic-password.path;
        initialize = true;
        timerConfig = {
          OnCalendar = "02:30";
          Persistent = true;
        };
        paths = [ "/persist/.${snap}" ] ++ map (root: inSnapshot root root) roots;
        exclude = [
          (inSnapshot "/srv/immich" "/srv/immich/library/thumbs")
          (inSnapshot "/srv/immich" "/srv/immich/library/encoded-video")
          "/persist/.${snap}/.restic-*"
        ]
        ++ persisted;
        extraBackupArgs = [ "--retry-lock 30m" ];
        pruneOpts = [
          "--retry-lock 30m"
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
        backupPrepareCommand = ''
          set -euo pipefail
          ${release}
          for db in ${lib.escapeShellArgs databases}; do
            systemctl start "postgresqlBackup-$db.service" || echo "Dump of $db failed; backing up the last good one."
          done
          for dataset in ${lib.escapeShellArgs datasets}; do
            zfs snapshot "$dataset@${snap}"
          done
          btrfs subvolume snapshot -r /persist /persist/.${snap}
        '';
        backupCleanupCommand = release;
      };

      systemd = {
        services = lib.mkMerge [
          {
            "restic-backups-${name}" = {
              path = [
                config.boot.zfs.package
                pkgs.btrfs-progs
              ];
              unitConfig.RequiresMountsFor = roots ++ [ "/mnt/backup" ];
              serviceConfig.PrivateNetwork = true;
            };
            "restic-drill-${name}" = {
              description = "Read a twelfth of the USB backup and test the latest database dumps";
              after = [ "restic-backups-${name}.service" ];
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
                CacheDirectory = "restic-drill-${name}";
                Environment = "RESTIC_CACHE_DIR=%C/restic-drill-${name}";
                TimeoutStartSec = "12h";
              };
              path = [ pkgs.gzip ];
              script = ''
                set -o pipefail
                ${restic} check --retry-lock 30m --read-data-subset="$(date +%-m)/12"
                for db in ${lib.escapeShellArgs databases}; do
                  dump=${inSnapshot "/srv" "${dumpDir}/$db"}
                  if ! ${restic} ls latest "$dump.sql.gz" > /dev/null 2>&1; then
                    echo "The latest snapshot has no fresh dump of $db; testing the previous one."
                    dump=$dump.prev
                  fi
                  ${restic} dump latest "$dump.sql.gz" | gzip -t
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
        timers."restic-drill-${name}".timerConfig = {
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
