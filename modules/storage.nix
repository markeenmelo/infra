{
  config,
  inputs,
  ...
}:
let
  inherit (config.fleet.hosts.bastion) system;
  probe = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      config.flake.modules.nixos.storage
      {
        nixpkgs.hostPlatform = system;
        system.stateVersion = "26.05";
        fleet.encryptState = false;
        disko.devices.disk.os.device = "/dev/vda";
        preservation.preserveAt."/persist".directories = [ "/var/lib/probe" ];
      }
    ];
  };
in
{
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.storage ];

  flake.checks.${system}.storage = inputs.disko.lib.testLib.makeDiskoTest {
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    name = "storage";
    disko-config.disko.devices = probe.config.disko.devices;
    inherit (probe) extendModules;
    extraTestScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("touch /stray /var/lib/probe/kept")
      machine_id = machine.succeed("cat /etc/machine-id")
      root_id = machine.succeed("btrfs inspect-internal rootid /")
      machine.shutdown()
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.fail("test -e /stray")
      machine.succeed("test -e /var/lib/probe/kept")
      assert machine.succeed("cat /etc/machine-id") == machine_id, "machine-id changed across a reboot"
      assert machine.succeed("btrfs inspect-internal rootid /") != root_id, "root subvolume was not recreated"
    '';
  };

  flake.modules.nixos.storage =
    {
      config,
      lib,
      utils,
      ...
    }:
    let
      root = config.fileSystems."/".device;
      btrfs = {
        type = "btrfs";
        subvolumes = lib.genAttrs [ "root" "nix" "persist" ] (name: {
          mountpoint = if name == "root" then "/" else "/${name}";
          mountOptions = [
            "compress=zstd"
            "noatime"
          ];
        });
      };
      esp = {
        type = "filesystem";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = [ "umask=0077" ];
      };
      state =
        if config.fleet.encryptState then
          {
            type = "luks";
            name = "state";
            settings.allowDiscards = true;
            content = btrfs;
          }
        else
          btrfs;
    in
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.preservation.nixosModules.preservation
      ];
      options.fleet = {
        encryptState = lib.mkOption {
          type = lib.types.bool;
          description = "Whether the state partition is LUKS, opened at boot by its TPM2 token or the passphrase.";
        };
        esp = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "An ESP another OS created and owns, mounted at /boot and never formatted; when set, `disko.devices.disk.os.device` is the state partition itself and nothing is partitioned.";
        };
      };
      config = {
        disko.devices.disk = {
          os.content =
            if config.fleet.esp == null then
              {
                type = "gpt";
                partitions = {
                  boot = {
                    type = lib.mkDefault "EF00";
                    size = lib.mkDefault "2G";
                    content = esp;
                  };
                  state = {
                    size = "100%";
                    content = state;
                  };
                };
              }
            else
              state;
          esp = lib.mkIf (config.fleet.esp != null) {
            device = config.fleet.esp;
            destroy = false;
            content = esp;
          };
        };
        fileSystems."/persist".neededForBoot = true;
        services.btrfs.autoScrub = {
          enable = true;
          fileSystems = [ "/persist" ];
        };

        boot.initrd.systemd.services.root-reset = {
          wantedBy = [ "initrd.target" ];
          requires = [ "${utils.escapeSystemdPath root}.device" ];
          after = [ "${utils.escapeSystemdPath root}.device" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig.Type = "oneshot";
          enableStrictShellChecks = true;
          script = ''
            mkdir -p /btrfs
            mount -t btrfs -o subvol=/ ${root} /btrfs
            if [ -e /btrfs/root ]; then
              btrfs subvolume delete --recursive /btrfs/root
            fi
            btrfs subvolume create /btrfs/root
            umount /btrfs
          '';
        };

        preservation = {
          enable = true;
          preserveAt."/persist" = {
            directories = [
              {
                directory = "/var/lib/nixos";
                inInitrd = true;
              }
              "/var/lib/systemd/timers"
            ];
            files = [
              {
                file = "/etc/machine-id";
                inInitrd = true;
              }
              {
                file = "/var/lib/systemd/random-seed";
                how = "symlink";
                inInitrd = true;
                configureParent = true;
              }
            ];
          };
        };
        systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];
      };
    };
}
