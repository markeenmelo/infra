{
  config,
  inputs,
  ...
}:
let
  inherit (config.fleet.hosts.bastion) system;
  layout = lib: root: {
    type = "gpt";
    partitions = {
      boot = {
        type = lib.mkDefault "EF00";
        size = lib.mkDefault "2G";
        content = {
          type = "filesystem";
          format = "vfat";
          mountpoint = "/boot";
          mountOptions = [ "umask=0077" ];
        };
      };
      state = {
        size = "100%";
        content = {
          type = "luks";
          name = "state";
          settings.allowDiscards = true;
          content = root;
        };
      };
    };
  };
  keyFile = "/tmp/secret.key";
  probeWith =
    storage: extra:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        inputs.disko.nixosModules.disko
        inputs.preservation.nixosModules.preservation
        storage
        (
          { pkgs, ... }:
          {
            nixpkgs.hostPlatform = system;
            system.stateVersion = "26.05";
            disko.devices.disk.os.device = "/dev/vda";
            preservation.preserveAt."/persist".directories = [ "/var/lib/probe" ];
            boot.initrd.secrets.${keyFile} = pkgs.writeText "secret.key" "secretsecret";
          }
        )
        extra
      ];
    };
  keyed.disko.devices.disk.os.content.partitions.state.content.settings = { inherit keyFile; };
  probe = probeWith config.flake.modules.nixos.storage keyed;
  probePlain = probeWith config.flake.modules.nixos.plain-storage keyed;
  probePerlless = probeWith config.flake.modules.nixos.storage (
    { modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/profiles/perlless.nix")
        keyed
      ];
      boot.loader.limine = {
        enable = true;
        efiInstallAsRemovable = true;
      };
      services.userborn.passwordFilesLocation = "/var/lib/nixos";
      users = {
        users.probe = {
          isSystemUser = true;
          group = "probe";
        };
        groups.probe = { };
      };
    }
  );
  survivesReboot = ''
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
in
{
  flake.modules.nixos.base.imports = [
    inputs.disko.nixosModules.disko
    inputs.preservation.nixosModules.preservation
  ];

  flake.checks.${system} = {
    storage = inputs.disko.lib.testLib.makeDiskoTest {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      name = "storage";
      disko-config.disko.devices = probe.config.disko.devices;
      inherit (probe) extendModules;
      extraTestScript = ''
        machine.succeed("cryptsetup status state")
      ''
      + survivesReboot;
    };
    plain-storage = inputs.disko.lib.testLib.makeDiskoTest {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      name = "plain-storage";
      disko-config.disko.devices = probePlain.config.disko.devices;
      inherit (probePlain) extendModules;
      extraTestScript = ''
        machine.wait_for_unit("multi-user.target")
        machine.succeed("cryptsetup status state")
        machine.succeed("findmnt --types ext4 /")
        machine.succeed("touch /kept")
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.succeed("test -e /kept")
      '';
    };
    storage-perlless = inputs.disko.lib.testLib.makeDiskoTest {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      name = "storage-perlless";
      disko-config.disko.devices = probePerlless.config.disko.devices;
      inherit (probePerlless) extendModules;
      extraTestScript = ''
        machine.wait_for_unit("multi-user.target")
        machine.succeed("findmnt --types overlay /etc")
        machine.succeed("test -s /persist/var/lib/nixos/passwd")
        probe_id = machine.succeed("id -u probe")
      ''
      + survivesReboot
      + ''
        assert machine.succeed("id -u probe") == probe_id, "an account's id changed across a reboot"
      '';
    };
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
    in
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.preservation.nixosModules.preservation
      ];
      config = {
        disko.devices.disk.os.content = layout lib btrfs;
        fileSystems."/persist".neededForBoot = true;
        services.btrfs.autoScrub = {
          enable = true;
          fileSystems = [ "/persist" ];
        };

        boot.initrd.systemd.services.root-reset = {
          wantedBy = [ "initrd.target" ];
          requiredBy = [ "sysroot.mount" ];
          requires = [ "${utils.escapeSystemdPath root}.device" ];
          after = [ "${utils.escapeSystemdPath root}.device" ];
          before = [ "sysroot.mount" ];
          unitConfig.DefaultDependencies = "no";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
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

  flake.modules.nixos.plain-storage =
    { lib, ... }:
    {
      disko.devices.disk.os.content = layout lib {
        type = "filesystem";
        format = "ext4";
        mountpoint = "/";
        mountOptions = [ "noatime" ];
      };
    };
}
