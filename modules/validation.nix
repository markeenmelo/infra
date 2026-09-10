{
  config,
  inputs,
  lib,
  options,
  ...
}:
let
  # Independent policy oracle: changing host metadata alone must fail validation.
  expectedTracks = {
    thinkpad = "unstable";
    dino = "unstable";
    racknerd = "stable";
    bastion = "stable";
  };
  tracks = {
    stable = inputs.nixpkgs-stable;
    unstable = inputs.nixpkgs-unstable;
  };
  modules = config.flake.modules.nixos;
  report = config.flake.fleet;
  lock = builtins.fromJSON (builtins.readFile (inputs.self + "/flake.lock"));
  lockedInput = name: lock.nodes.${lock.nodes.root.inputs.${name}};
  checkedReport =
    assert lib.assertMsg (
      builtins.match "nixos-[0-9]{2}\\.(05|11)" (lockedInput "nixpkgs-stable").original.ref != null
    ) "Stable must lock a numbered NixOS release branch, not an unstable alias.";
    assert lib.assertMsg (
      (lockedInput "nixpkgs-unstable").original.ref == "nixpkgs-unstable"
    ) "Interactive track must lock nixpkgs-unstable.";
    assert lib.assertMsg
      (
        !(lock.nodes.root.inputs ? home-manager-stable)
        && !(lock.nodes.root.inputs ? home-manager-unstable)
        &&
          (lockedInput "home-manager").original == {
            type = "github";
            owner = "nix-community";
            repo = "home-manager";
          }
        && ((lockedInput "home-manager").flake or true)
        && (lockedInput "home-manager").inputs.nixpkgs == [ "nixpkgs-unstable" ]
        &&
          (lockedInput "zen-browser").original == {
            type = "github";
            owner = "youwen5";
            repo = "zen-browser-flake";
          }
        && ((lockedInput "zen-browser").flake or true)
        && (lockedInput "zen-browser").inputs.nixpkgs == [ "nixpkgs-unstable" ]
      )
      "Home Manager and Zen must be default-branch flakes following unstable, pinned only in flake.lock.";
    assert lib.assertMsg (
      builtins.attrNames expectedTracks == builtins.attrNames report
    ) "Update the explicit fleet policy oracle when adding/removing a host.";
    lib.mapAttrs (
      name: host:
      let
        system = config.flake.fleetConfigurations.${name};
        cfg = system.config;
      in
      assert lib.assertMsg (host.track == expectedTracks.${name}) "${name}: wrong Nixpkgs track";
      assert lib.assertMsg
        (
          lib.versions.major cfg.boot.kernelPackages.kernel.version == "7"
          && cfg.boot.kernelPackages.kernel.drvPath == system.pkgs.linuxPackages_latest.kernel.drvPath
          && !(lib.elem "xe" cfg.boot.initrd.kernelModules)
          && !(lib.any (lib.hasInfix "force_probe") cfg.boot.kernelParams)
        )
        "${name}: retain the host track's latest stock 7.x kernel and no experimental Intel force-probe policy";
      assert lib.assertMsg (
        host.nixpkgsPath == host.intendedNixpkgsPath
        && host.nixpkgsPath == toString tracks.${expectedTracks.${name}}.outPath
      ) "${name}: actual pkgs source differs from independently required input";
      assert lib.assertMsg (lib.all
        (
          message:
          lib.hasPrefix "BOOTSTRAP:" message
          || lib.hasPrefix "Neither the root account nor any wheel user has a password or SSH authorized key." message
        )
        host.failedAssertions
      ) "${name}: unexpected NixOS assertion: ${lib.concatStringsSep "; " host.failedAssertions}";
      assert lib.assertMsg (
        host.ready -> host.missing == [ ] && host.failedAssertions == [ ]
      ) "${name}: commissioned with unresolved requirements";
      assert lib.assertMsg (
        host.storageMode == "existing"
        && cfg.disko.devices.disk == { }
        && cfg.disko.devices.zpool == { }
        && cfg.fileSystems."/".fsType == "tmpfs"
        && cfg.fileSystems."/nix".neededForBoot
        && cfg.fileSystems."/persist".neededForBoot
        && cfg.boot.loader.limine.enable
        && !cfg.boot.loader.limine.force
        && !cfg.boot.loader.grub.enable
        && !cfg.boot.loader.systemd-boot.enable
      ) "${name}: real hosts must preserve existing storage and use Limine";
      assert lib.all
        (
          output:
          lib.assertMsg (
            !(builtins.tryEval cfg.system.build.${output}.drvPath).success
          ) "${name}: real host exposed provisioning output ${output}"
        )
        [
          "diskoScript"
          "destroyFormatMount"
          "format"
          "mount"
          "diskoImages"
        ];
      assert lib.assertMsg (
        !cfg.services.tailscale.enable
        && !cfg.services.xserver.enable
        && !cfg.programs.steam.enable
        && cfg.systemd.enableEmergencyMode
        && cfg.services.openssh.settings.PermitRootLogin == "no"
        && cfg.services.openssh.settings.AllowUsers == [ "marcos" ]
        && cfg.security.sudo.wheelNeedsPassword
        && !cfg.fleet.access.passwordlessSudo
        && cfg.networking.firewall.allowedTCPPorts == [ 22 ]
        && cfg.networking.firewall.allowedUDPPorts == (if name == "thinkpad" then [ 5353 ] else [ ])
        &&
          cfg.networking.firewall.allowedTCPPortRanges == (
            if name == "thinkpad" then
              [
                {
                  from = 1714;
                  to = 1764;
                }
              ]
            else
              [ ]
          )
        && cfg.networking.firewall.allowedUDPPortRanges == cfg.networking.firewall.allowedTCPPortRanges
      ) "${name}: SSH/firewall/no-VPN/recovery policy regressed";
      assert lib.assertMsg (
        if name == "thinkpad" then
          cfg.programs.hyprland.enable
          && cfg.programs.hyprland.withUWSM
          && cfg.services.greetd.enable
          && cfg.services.displayManager.enable
          && !(cfg.services.greetd.settings ? initial_session)
          && builtins.attrNames cfg.home-manager.users == [ "marcos" ]
          && cfg.home-manager.useGlobalPkgs
          && cfg.home-manager.useUserPackages
          && cfg.home-manager.users.marcos.home.stateVersion == "26.05"
          && !cfg.home-manager.users.marcos.home.version.isReleaseBranch
          && cfg.home-manager.users.marcos.warnings == [ ]
          && !cfg.hardware.graphics.enable32Bit
          && lib.all (module: lib.elem module cfg.boot.initrd.availableKernelModules) [
            "xhci_pci"
            "thunderbolt"
            "nvme"
            "usb_storage"
            "usbhid"
            "sd_mod"
          ]
          && lib.elem "dm-snapshot" cfg.boot.initrd.kernelModules
          && lib.elem "kvm-intel" cfg.boot.kernelModules
          && !(lib.elem "nvidia" cfg.services.xserver.videoDrivers)
          &&
            lib.hasInfix "1920x1200@60.003"
              cfg.home-manager.users.marcos.xdg.configFile."hypr/hyprland.lua".text
        else
          !cfg.programs.hyprland.enable
          && !cfg.services.displayManager.enable
          && !cfg.services.greetd.enable
          && !(system.options ? home-manager)
          && !cfg.services.fprintd.enable
          && !cfg.hardware.bluetooth.enable
          && !cfg.services.printing.enable
          && !cfg.programs.kdeconnect.enable
      ) "${name}: only ThinkPad may opt into the new Intel-first desktop; other hosts remain headless";
      assert lib.assertMsg (
        cfg.programs.nh.enable == (name == "thinkpad")
        && !cfg.programs.nh.clean.enable
        && !(cfg.systemd.services ? nh-clean)
        && !(cfg.systemd.timers ? nh-clean)
        && cfg.programs.nh.flake == (if name == "thinkpad" then "/home/marcos/projects/infra" else null)
        && (
          if name == "thinkpad" then
            cfg.programs.nh.package.drvPath == system.pkgs.nh.drvPath
            && cfg.environment.variables.NH_FLAKE == "/home/marcos/projects/infra"
          else
            !(cfg.environment.variables ? NH_FLAKE)
        )
      ) "${name}: nh is ThinkPad-only, uses its own pkgs/checkout and must not schedule cleanup";
      assert lib.assertMsg (
        cfg.sops.age.keyFile == cfg.fleet.secrets.ageKeyFile
        && !cfg.sops.age.generateKey
        && cfg.sops.age.sshKeyPaths == [ ]
        && cfg.sops.gnupg.sshKeyPaths == [ ]
        && cfg.sops.validateSopsFiles
        && !cfg.sops.useTmpfs
        && cfg.fleet.access.passwordSecrets ? marcos
        && (
          name != "thinkpad"
          || (
            cfg.fleet.access.passwordSecrets.marcos == "marcos-password-hash"
            && cfg.users.users.marcos.hashedPasswordFile == cfg.sops.secrets.marcos-password-hash.path
            && cfg.sops.secrets.marcos-password-hash.neededForUsers
            &&
              builtins.attrNames cfg.sops.secrets == (
                [ "marcos-password-hash" ]
                ++ lib.optionals (cfg.fleet.wifi.senecaSopsFile != null) [
                  "seneca-identity"
                  "seneca-password"
                ]
                ++ [ "wifi-psk" ]
              )
          )
        )
      ) "${name}: SOPS identity/password policy regressed or unrelated secrets enabled";
      assert lib.assertMsg (
        (lib.elem name [
          "thinkpad"
          "dino"
        ])
        -> (
          cfg.fileSystems."/home".neededForBoot
          && !(lib.elem "/home" host.persistence.directories)
          && cfg.services.power-profiles-daemon.enable
        )
      ) "${name}: preserve laptop home mounts and power management";
      host
      // {
        # Force real per-host packages, /etc/services and initrd even before the
        # final toplevel is permitted. These are evaluations, not real builds.
        components = {
          systemPath = system.config.system.path.drvPath;
          etc = system.config.system.build.etc.drvPath;
          initrd = system.config.system.build.initialRamdisk.drvPath;
          kernel = cfg.boot.kernelPackages.kernel.drvPath;
          kernelVersion = cfg.boot.kernelPackages.kernel.version;
        }
        // lib.optionalAttrs (name == "bastion") {
          zfs = cfg.boot.kernelPackages.${cfg.boot.zfs.package.kernelModuleAttribute}.drvPath;
          zfsVersion = cfg.boot.zfs.package.version;
        }
        // lib.optionalAttrs (name == "thinkpad") {
          home = cfg.home-manager.users.marcos.home.activationPackage.drvPath;
        };
      }
    ) report;

  # Deliberately synthetic EVALUATION fixtures, never installable fleet members.
  # No fixture scripts are exported as provisioning packages or deploy nodes.
  allCapabilities = [
    "os-disk"
    "headless"
    "persistence"
    "access"
    "server"
    "vps"
    "workstation"
    "laptop"
    "gaming"
    "nas"
    "administration"
  ];
  fixtureFor =
    track: bootMode: capabilities:
    tracks.${track}.lib.nixosSystem {
      modules = [
        modules.base
      ]
      ++ lib.optional (lib.elem "hyprland" capabilities) inputs.home-manager.nixosModules.home-manager
      ++ map (name: modules.${name}) capabilities
      ++ [
        ({ lib, pkgs, ... }: {
          nixpkgs.hostPlatform = "x86_64-linux";
          networking.hostName = "evaluation-fixture";
          fleet = {
            bootstrap.approved = true;
            installation = {
              stateVersion = lib.versions.majorMinor pkgs.lib.version;
              hardwareReviewed = true;
              networkReviewed = true;
            };
            access = {
              admin = "fixture-admin";
              authorizedKeys = [ "ssh-ed25519 TEST-ONLY-NOT-A-VALID-KEY" ];
              passwordSecrets.fixture-admin = "TEST-ONLY-password";
              passwordlessSudo = false;
            };
            secrets = {
              ageKeyFile = "/persist/var/lib/sops-nix/TEST-ONLY-NO-IDENTITY";
              identityReviewed = true;
            };
          }
          // lib.optionalAttrs (lib.elem "os-disk" capabilities) {
            osDisk = {
              device = "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK";
              confirmed = true;
              inherit bootMode;
              espSize = if bootMode == "uefi" then "512M" else null;
              efiCanTouchVariables = false;
            };
          }
          // lib.optionalAttrs (lib.elem "existing-storage" capabilities) {
            existingStorage = {
              osDevice = "/dev/disk/by-id/TEST-ONLY-NOT-A-REAL-DISK";
              inherit bootMode;
              efiCanTouchVariables = false;
              biosPartitionIndex = if bootMode == "bios" then 1 else null;
              bootReviewed = true;
              migrationReviewed = true;
            };
          }
          // lib.optionalAttrs (lib.elem "workstation" capabilities) {
            workstation.usersReviewed = true;
          }
          // lib.optionalAttrs (lib.elem "hyprland" capabilities) {
            desktop.reviewed = true;
          }
          // lib.optionalAttrs (lib.elem "gaming" capabilities) {
            gaming.reviewed = true;
          }
          // lib.optionalAttrs (lib.elem "nas" capabilities) {
            nas.storageReviewed = true;
          }
          // lib.optionalAttrs (lib.elem "vps" capabilities) {
            vps.providerReviewed = true;
          };
          # Parse the shipped ciphertext with a synthetic consumer. There is no
          # matching fixture identity, decryption, install or exported target.
          sops.secrets.TEST-ONLY-password = {
            sopsFile = ../secrets/hosts/thinkpad.yaml;
            key = "marcos-password-hash";
            neededForUsers = true;
          };
          disko.devices.nodev = lib.optionalAttrs (lib.elem "existing-storage" capabilities) {
            "/boot" = {
              device = "/dev/disk/by-uuid/TEST-ONLY-ESP";
              fsType = "vfat";
              mountOptions = [ "umask=0077" ];
            };
            "/nix" = {
              device = "/dev/disk/by-uuid/TEST-ONLY-STATE";
              fsType = "btrfs";
              mountOptions = [ "subvol=nix" ];
            };
            "/persist" = {
              device = "/dev/disk/by-uuid/TEST-ONLY-STATE";
              fsType = "btrfs";
              mountOptions = [ "subvol=persist" ];
            };
          };
        })
        (lib.optionalAttrs (lib.elem "hyprland" capabilities) {
          home-manager.users.fixture-admin.home.stateVersion = "26.05";
        })
      ];
    };
  fixtures = lib.genAttrs (builtins.attrNames tracks) (
    track: fixtureFor track "uefi" allCapabilities
  );
  compositionReport = lib.mapAttrs (
    _: host:
    let
      fixture = fixtureFor host.track "uefi" host.capabilities;
    in
    {
      # Also check the exact shipped subsets: a combined fixture alone can mask
      # a missing dependency by supplying another capability's configuration.
      toplevel = fixture.config.system.build.toplevel.drvPath;
    }
  ) config.fleet.hosts;
  existingReport = lib.genAttrs (builtins.attrNames tracks) (
    track:
    let
      capabilities = [ "existing-storage" ] ++ lib.filter (name: name != "os-disk") allCapabilities;
      fixture = fixtureFor track "uefi" capabilities;
      cfg = fixture.config;
      bios = (fixtureFor track "bios" capabilities).config;
      pending = fixture.extendModules {
        modules = [
          {
            fleet = {
              bootstrap.approved = lib.mkForce false;
              existingStorage.bootReviewed = lib.mkForce false;
              existingStorage.migrationReviewed = lib.mkForce false;
            };
          }
        ];
      };
      missingReview = fixture.extendModules {
        modules = [
          {
            fleet.existingStorage.migrationReviewed = lib.mkForce false;
          }
        ];
      };
      home =
        (fixture.extendModules {
          modules = [
            {
              fleet.workstation.homePersistence = "filesystem";
              disko.devices.nodev."/home" = {
                device = "/dev/disk/by-uuid/TEST-ONLY-STATE";
                fsType = "btrfs";
                mountOptions = [ "subvol=home" ];
              };
              fileSystems."/home".neededForBoot = true;
            }
          ];
        }).config;
      injected =
        (fixture.extendModules {
          modules = [
            {
              disko.devices.disk.unwanted = {
                type = "disk";
                device = "/dev/disk/by-id/TEST-ONLY-DATA";
              };
            }
          ];
        }).config;
      scriptNames = builtins.attrNames (cfg.disko.devices._scripts { inherit (fixture) pkgs; }) ++ [
        "disko"
        "diskoNoDeps"
        "installTest"
        "vmWithDisko"
        "diskoImages"
        "diskoImagesScript"
      ];
    in
    assert lib.assertMsg (
      cfg.fleet.bootstrap.missing == [ ] && lib.all (a: a.assertion) cfg.assertions
    ) "${track}: existing-installation fixture failed";
    assert lib.assertMsg (
      cfg.fileSystems."/".fsType == "tmpfs"
      && cfg.fileSystems."/nix".neededForBoot
      && cfg.fileSystems."/persist".neededForBoot
      && cfg.fileSystems."/nix".device == "/dev/disk/by-uuid/TEST-ONLY-STATE"
      && lib.elem "subvol=persist" cfg.fileSystems."/persist".options
    ) "${track}: existing mounts must retain identities and early persistence";
    assert lib.assertMsg (
      injected.disko.devices.disk == { }
      && cfg.disko.devices.zpool == { }
      && cfg.disko.devices.lvm_vg == { }
      && cfg.disko.devices.mdadm == { }
    ) "${track}: existing installs must not expose destructive device nodes";
    assert lib.all (
      name:
      lib.assertMsg (
        !(builtins.tryEval cfg.system.build.${name}.drvPath).success
        && !(builtins.tryEval pending.config.system.build.${name}.drvPath).success
      ) "${track}: existing install exposed ${name}"
    ) scriptNames;
    assert lib.assertMsg (
      !(builtins.tryEval missingReview.config.system.build.toplevel.drvPath).success
    ) "${track}: ready alone must not bypass migration review";
    assert lib.assertMsg (
      cfg.boot.loader.limine.enable
      && cfg.boot.loader.limine.efiSupport
      && !cfg.boot.loader.limine.biosSupport
      && !cfg.boot.loader.limine.enableEditor
      && !cfg.boot.loader.limine.force
      && cfg.boot.loader.limine.validateChecksums
      && !cfg.boot.loader.grub.enable
      && !cfg.boot.loader.systemd-boot.enable
      && bios.boot.loader.limine.biosSupport
      && !bios.boot.loader.limine.efiSupport
      && bios.boot.loader.limine.partitionIndex == 1
      && bios.fileSystems."/boot".fsType == "vfat"
    ) "${track}: Limine EFI/BIOS policy regressed";
    assert lib.assertMsg (
      !(lib.elem "/home" (map (d: d.dirPath) home.environment.persistence."/persist".directories))
      && home.fileSystems."/home".neededForBoot
    ) "${track}: separate /home must not also be an impermanence bind";
    assert lib.assertMsg (
      cfg.services.openssh.settings.PermitRootLogin == "no"
      && cfg.services.openssh.settings.AuthenticationMethods == "publickey"
      && cfg.services.openssh.settings.AllowUsers == [ "fixture-admin" ]
      && cfg.networking.firewall.allowedTCPPorts == [ 22 ]
      && cfg.networking.firewall.allowedUDPPorts == [ ]
      && cfg.services.fail2ban.enable
      && cfg.services.fail2ban.banaction == "nftables-multiport"
      && lib.elem "/var/lib/fail2ban" (
        map (d: d.dirPath) cfg.environment.persistence."/persist".directories
      )
      && cfg.services.fail2ban.jails.DEFAULT.settings.backend == "systemd"
      && !cfg.fleet.access.passwordlessSudo
      && cfg.security.sudo.wheelNeedsPassword
      && cfg.users.users.fixture-admin.hashedPasswordFile == "/run/secrets-for-users/TEST-ONLY-password"
      && cfg.nix.settings.trusted-users == [ "root" ]
      && cfg.services.power-profiles-daemon.enable
      && !cfg.services.tlp.enable
      && !cfg.services.xserver.enable
      && !cfg.services.tailscale.enable
      && !cfg.programs.steam.enable
      && cfg.systemd.enableEmergencyMode
    ) "${track}: headless security/power/recovery baseline regressed";
    {
      toplevel = cfg.system.build.toplevel.drvPath;
      biosToplevel = bios.system.build.toplevel.drvPath;
      homeToplevel = home.system.build.toplevel.drvPath;
      bootloader = cfg.system.build.installBootLoader.drvPath;
      inherit scriptNames;
      provisioningBlocked = true;
      migrationReviewRequired = true;
    }
  );
  sopsReport = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      rejected =
        module:
        !(builtins.tryEval
          (fixture.extendModules { modules = [ module ]; }).config.system.build.toplevel.drvPath
        ).success;
      missing =
        (fixture.extendModules {
          modules = [ { fleet.access.passwordSecrets.fixture-admin = lib.mkForce null; } ];
        }).config;
    in
    assert lib.assertMsg (
      cfg.users.users.fixture-admin.hashedPasswordFile == cfg.sops.secrets.TEST-ONLY-password.path
      && cfg.sops.secrets.TEST-ONLY-password.path == "/run/secrets-for-users/TEST-ONLY-password"
      && cfg.sops.secrets.TEST-ONLY-password.neededForUsers
      && cfg.sops.secrets.TEST-ONLY-password.mode == "0400"
      && !cfg.users.mutableUsers
      && cfg.security.sudo.wheelNeedsPassword
      && !cfg.fleet.access.passwordlessSudo
      && lib.elem "setupSecretsForUsers" cfg.system.activationScripts.users.deps
      && lib.elem "specialfs" cfg.system.activationScripts.setupSecretsForUsers.deps
      && cfg.sops.age.keyFile == cfg.fleet.secrets.ageKeyFile
      && cfg.sops.age.sshKeyPaths == [ ]
      && cfg.sops.gnupg.sshKeyPaths == [ ]
      && !cfg.sops.age.generateKey
      && cfg.sops.validateSopsFiles
      && !cfg.sops.useTmpfs
      && !cfg.services.userborn.enable
      && !cfg.systemd.sysusers.enable
      && !cfg.sops.useSystemdActivation
      &&
        cfg.sops.package.drvPath == (fixture.pkgs.callPackage inputs.sops-nix { })
        .sops-install-secrets.drvPath
    ) "${track}: early SOPS password delivery or target-package isolation regressed";
    assert lib.assertMsg (
      missing.users.users.fixture-admin.hashedPassword == "!"
      && missing.users.users.fixture-admin.hashedPasswordFile == null
      && lib.elem "Supply a declared SOPS password-hash secret in fleet.access.passwordSecrets.fixture-admin." missing.fleet.bootstrap.missing
      && !(builtins.tryEval missing.system.build.toplevel.drvPath).success
    ) "${track}: missing credentials must stay locked and block commissioning";
    assert lib.all
      (
        module:
        lib.assertMsg (rejected module) "${track}: unsafe SOPS password/identity configuration was accepted"
      )
      [
        { fleet.access.passwordSecrets.fixture-admin = lib.mkForce "TEST-ONLY-UNDECLARED"; }
        { fleet.secrets.ageKeyFile = lib.mkForce null; }
        { fleet.secrets.identityReviewed = lib.mkForce false; }
        { fileSystems."/persist".neededForBoot = lib.mkForce false; }
        { sops.secrets.TEST-ONLY-password.neededForUsers = lib.mkForce false; }
        { sops.secrets.TEST-ONLY-password.mode = lib.mkForce "0444"; }
        { sops.secrets.TEST-ONLY-password.name = lib.mkForce "../TEST-ONLY-password"; }
        { users.mutableUsers = lib.mkForce true; }
        { sops.secrets.TEST-ONLY-password.path = lib.mkForce "/persist/secrets/TEST-ONLY-password"; }
        { sops.age.generateKey = lib.mkForce true; }
        { sops.age.sshKeyPaths = lib.mkForce [ "/persist/etc/ssh/ssh_host_ed25519_key" ]; }
        { sops.validateSopsFiles = lib.mkForce false; }
        { sops.useTmpfs = lib.mkForce true; }
        { services.userborn.enable = lib.mkForce true; }
        { users.users.fixture-admin.hashedPassword = "!"; }
      ];
    {
      usersManifest = cfg.system.build.sops-nix-users-manifest.drvPath;
      installer = cfg.sops.package.drvPath;
      toplevel = cfg.system.build.toplevel.drvPath;
      missingCredentialsBlocked = true;
      unsafeOverridesRejected = true;
    }
  ) fixtures;
  desktopFixtures = lib.genAttrs [ "unstable" ] (
    track:
    fixtureFor track "uefi" [
      "os-disk"
      "ssh"
      "hyprland"
      "persistence"
      "access"
      "workstation"
      "laptop"
    ]
  );
  desktopReport = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      home = cfg.home-manager.users.fixture-admin;
      rejected =
        module:
        !(builtins.tryEval
          (fixture.extendModules { modules = [ module ]; }).config.system.build.toplevel.drvPath
        ).success;
    in
    assert lib.assertMsg
      (
        cfg.fleet.bootstrap.missing == [ ]
        && lib.all (a: a.assertion) cfg.assertions
        && home.warnings == [ ]
        && cfg.home-manager.useGlobalPkgs
        && cfg.home-manager.useUserPackages
        && cfg.home-manager.backupFileExtension == null
        && builtins.attrNames cfg.home-manager.extraSpecialArgs == [ "nixosConfig" ]
        && !home.home.version.isReleaseBranch
        && lib.elem fixture.pkgs.noctalia home.home.packages
        && cfg.programs.hyprland.package.version == fixture.pkgs.hyprland.version
        && cfg.hardware.graphics.enable
        && !cfg.hardware.graphics.enable32Bit
        && cfg.programs.hyprland.withUWSM
        && cfg.programs.uwsm.enable
        &&
          cfg.programs.uwsm.waylandCompositors.hyprland.binPath == "/run/current-system/sw/bin/start-hyprland"
        && cfg.services.greetd.enable
        && cfg.services.displayManager.noctalia-greeter.enable
        && !cfg.services.greetd.useTextGreeter
        && cfg.services.fprintd.enable
        && cfg.security.pam.services.greetd.rules.auth.login.modulePath == "noctalia-greetd"
        &&
          cfg.security.pam.services.noctalia-greetd.rules.auth.unix.order
          < cfg.security.pam.services.noctalia-greetd.rules.auth.fprintd.order
        &&
          cfg.security.pam.services.sudo.rules.auth.unix.order
          < cfg.security.pam.services.sudo.rules.auth.fprintd.order
        && cfg.security.pam.services.noctalia-greetd.rules.auth.unix-early.enable
        && cfg.security.pam.services.noctalia-greetd.rules.auth.gnome_keyring.enable
        && cfg.security.pam.services.noctalia-greetd.rules.auth.unix.settings.use_first_pass
        && !cfg.security.pam.services.noctalia-greetd.rules.auth.unix.settings.try_first_pass
        && cfg.security.pam.services.greetd.rules.session.gnome_keyring.settings.auto_start
        && cfg.security.pam.services.noctalia-greetd.rules.auth.deny.enable
        && cfg.security.pam.services.sudo.rules.auth.deny.enable
        && !cfg.security.pam.services.noctalia-greetd.allowNullPassword
        && !cfg.security.pam.services.sudo.allowNullPassword
        && !cfg.security.pam.services.login.fprintAuth
        && !cfg.security.pam.services.sshd.fprintAuth
        && !cfg.services.gnome.gcr-ssh-agent.enable
        && !(cfg.services.greetd.settings ? initial_session)
        && !cfg.services.xserver.enable
        && cfg.systemd.enableEmergencyMode
        && cfg.services.pipewire.enable
        && cfg.services.pipewire.pulse.enable
        && cfg.services.gnome.gnome-keyring.enable
        && cfg.xdg.portal.config.hyprland."org.freedesktop.impl.portal.FileChooser" == "gtk"
        && home.systemd.user.services.noctalia.Unit.PartOf == [ "graphical-session.target" ]
        && home.systemd.user.services.noctalia.Service.ExecStart == [ (lib.getExe fixture.pkgs.noctalia) ]
        &&
          home.systemd.user.services.noctalia.Service.Environment == [
            "NOCTALIA_CONFIG_HOME=${home.xdg.configHome}/fleet-desktop"
            "NOCTALIA_STATE_HOME=${home.xdg.stateHome}/fleet-desktop"
            "NOCTALIA_DATA_HOME=${home.xdg.dataHome}/fleet-desktop"
          ]
        && home.xdg.configFile."noctalia/config.toml".target == ".config/fleet-desktop/noctalia/config.toml"
        && home.programs.noctalia.enable
        && home.programs.noctalia.settings.lockscreen.fingerprint
        && !home.programs.noctalia.settings.lockscreen.allow_empty_password
        && home.wayland.windowManager.hyprland.configType == "lua"
        && !home.wayland.windowManager.hyprland.systemd.enable
        && home.programs.ghostty.enable
        && home.programs.herdr.enable
        && home.programs.zed-editor.enable
        && home.programs.pi-coding-agent.enable
        && !home.programs.foot.enable
        && !home.programs.firefox.enable
        && home.sshAuthSock.enable
        && home.xdg.autostart.enable
        && !home.xdg.autostart.readOnly
        && home.services.kdeconnect.enable
        && !home.services.network-manager-applet.enable
        && lib.all (file: !file.force) (lib.attrValues home.home.file)
        && !(home.systemd.user.services ? hyprland)
        && !(home.systemd.user.services ? hypridle)
        && !(lib.hasInfix "AQ_DRM_DEVICES" home.xdg.configFile."hypr/hyprland.lua".text)
        && !(lib.hasInfix "__GLX_VENDOR_LIBRARY_NAME" home.xdg.configFile."hypr/hyprland.lua".text)
      )
      "${track}: desktop/Home Manager policy regressed; blockers: ${builtins.toJSON cfg.fleet.bootstrap.missing}; assertions: ${
        builtins.toJSON (map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions))
      }";
    assert lib.assertMsg (
      rejected { fleet.desktop.reviewed = lib.mkForce false; }
      && rejected { security.pam.services.noctalia-greetd.allowNullPassword = lib.mkForce true; }
      && rejected { security.pam.services.sudo.rules.auth.deny.enable = lib.mkForce false; }
      && rejected { security.pam.services.sshd.fprintAuth = true; }
      && rejected {
        services.greetd.settings.initial_session = {
          command = "false";
          user = "fixture-admin";
        };
      }
    ) "${track}: desktop review and authenticated login must not be bypassed";
    {
      toplevel = cfg.system.build.toplevel.drvPath;
      homeActivation = home.home.activationPackage.drvPath;
      hyprland = cfg.programs.hyprland.package.version;
      noctalia = fixture.pkgs.noctalia.version;
      homeManagerRevision = inputs.home-manager.rev;
      unreviewedDesktopRejected = true;
      autologinRejected = true;
      unsafePamRejected = true;
    }
  ) desktopFixtures;
  desktopConfigCheck =
    name: system: user:
    let
      cfg = system.config;
      home = cfg.home-manager.users.${user};
      browser = lib.findFirst (package: (package.pname or "") == "zen-browser") null home.home.packages;
    in
    assert lib.assertMsg
      (
        lib.elem system.pkgs.nerd-fonts.jetbrains-mono home.home.packages
        && !(lib.elem system.pkgs.jetbrains-mono home.home.packages)
        && !(lib.elem system.pkgs.jetbrains-mono home.programs.zed-editor.extraPackages)
        && home.fonts.fontconfig.defaultFonts.monospace == [ "JetBrainsMono Nerd Font" ]
        && home.programs.ghostty.settings.font-family == [ "JetBrainsMono Nerd Font" ]
        && home.programs.zed-editor.userSettings.buffer_font_family == "JetBrainsMono Nerd Font"
        && home.programs.zed-editor.userSettings.ui_font_family == "JetBrainsMono Nerd Font"
        && home.programs.zed-editor.userSettings.terminal.font_family == "JetBrainsMono Nerd Font"
        && cfg.fonts.fontconfig.defaultFonts.emoji == [ "Noto Color Emoji" ]
      )
      "${name}: use only JetBrainsMono Nerd Font for monospace apps; preserve native color-emoji fallback";
    system.pkgs.runCommand "${name}-desktop-config" { } ''
      export HOME="$TMPDIR/home"
      export XDG_RUNTIME_DIR="$TMPDIR/runtime"
      export XDG_CONFIG_HOME="$HOME/.config"
      mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"
      # This upstream mode parses the config without starting a compositor.
      ${lib.getExe cfg.programs.hyprland.package} --verify-config --config ${
        home.xdg.configFile."hypr/hyprland.lua".source
      }
      # Native HM validation is retained, plus a stricter warning gate: upstream
      # exits zero even for ignored/obsolete settings. Neither starts a session.
      ${lib.getExe system.pkgs.noctalia} config validate ${
        home.xdg.configFile."noctalia/config.toml".source
      } > noctalia.log 2>&1
      cat noctalia.log
      if grep -E 'WARN|ERROR' noctalia.log; then exit 1; fi
      install -Dm644 ${
        home.xdg.configFile."ghostty/themes/OLED Graphite".source
      } "$XDG_CONFIG_HOME/ghostty/themes/OLED Graphite"
      ${lib.getExe system.pkgs.ghostty} +validate-config --config-file=${
        home.xdg.configFile."ghostty/config".source
      }
      ${lib.getExe system.pkgs.python3} - <<'PY'
      import json, tomllib
      with open("${
        cfg.systemd.tmpfiles.settings."10-noctalia-greeter"."/var/lib/noctalia-greeter/greeter.toml"."L+".argument
      }", "rb") as stream:
          greeter = tomllib.load(stream)
      assert greeter["session"]["default"] == "Hyprland (UWSM)"
      assert greeter["auth"]["allow_empty_password"] is True  # UI submission only, not PAM nullok.
      for filename in ["${home.xdg.configFile."zed/settings.json".source}", "${
        home.home.file."${home.programs.pi-coding-agent.configDir}/settings.json".source
      }"]:
          with open(filename) as stream: json.load(stream)
      with open("${home.xdg.configFile."herdr/config.toml".source}", "rb") as stream: tomllib.load(stream)
      PY
      grep -qx 'Hidden=true' ${home.xdg.configFile.autostart.source}/nm-applet.desktop
      grep -qx 'Hidden=true' ${home.xdg.configFile.autostart.source}/org.kde.kdeconnect.daemon.desktop
      test -x ${browser}/bin/zen
      test -s ${browser}/share/applications/zen.desktop
      find ${system.pkgs.nerd-fonts.jetbrains-mono} -iname '*Regular.ttf' \
        -exec ${lib.getExe' system.pkgs.fontconfig "fc-scan"} --format '%{family}\n' {} + > font-families
      grep -Eq '^JetBrainsMono Nerd Font(,|$)' font-families
      ${lib.optionalString cfg.programs.nh.enable ''
        # Help/version only: no rebuild, activation, target contact or cleanup.
        ${lib.getExe cfg.programs.nh.package} --version
        ${lib.getExe cfg.programs.nh.package} os build --help > /dev/null
      ''}
      touch "$out"
    '';
  # Evaluation-only campus profile/manifest branch, never an exported host.
  # Key selection alone can pass on encrypted markers; actual credential/MAC
  # verification is a separate private operation, not performed by checks.
  senecaTemplate =
    (config.flake.fleetConfigurations.thinkpad.extendModules {
      modules = [
        { fleet.wifi.senecaSopsFile = lib.mkForce ../secrets/hosts/thinkpad-senecanet.yaml; }
      ];
    }).config;
  wifiReport =
    let
      thinkpad = config.flake.fleetConfigurations.thinkpad;
      cfg = thinkpad.config;
      campus = senecaTemplate.networking.networkmanager.ensureProfiles.profiles.SenecaNET;
      absent =
        (thinkpad.extendModules {
          modules = [
            {
              fleet.wifi.senecaSopsFile = lib.mkForce null;
            }
          ];
        }).config;
      home = cfg.networking.networkmanager.ensureProfiles.profiles.MN-Home;
    in
    assert lib.assertMsg
      (
        home.wifi-security.psk == "$HOME_WIFI_PSK"
        && home.wifi-security.psk-flags == 0
        && cfg.sops.secrets.wifi-psk.mode == "0400"
        && cfg.sops.secrets.wifi-psk.owner == "root"
        && cfg.networking.networkmanager.ensureProfiles.secrets.entries == [ ]
        &&
          cfg.networking.networkmanager.ensureProfiles.environmentFiles
          == [ "/run/fleet-wifi-environment/credentials.env" ]
        && lib.elem "fleet-wifi-environment.service" cfg.systemd.services.NetworkManager-ensure-profiles.requires
        && campus.wifi-security.key-mgmt == "wpa-eap"
        && campus."802-1x".eap == "peap"
        && campus."802-1x".phase2-auth == "mschapv2"
        && campus."802-1x".ca-cert == "/etc/ssl/certs/ca-certificates.crt"
        && campus."802-1x".domain-suffix-match == "senecapolytechnic.ca"
        && campus."802-1x".anonymous-identity == ""
        && campus."802-1x".identity == "$SENECA_IDENTITY"
        && campus."802-1x".password == "$SENECA_PASSWORD"
        && campus."802-1x".password-flags == 0
        && !campus.connection.autoconnect
        &&
          lib.all
            (
              name:
              let
                secret = senecaTemplate.sops.secrets.${name};
              in
              secret.mode == "0400"
              && secret.owner == "root"
              && secret.group == "root"
              && secret.sopsFile == ../secrets/hosts/thinkpad-senecanet.yaml
            )
            [
              "seneca-identity"
              "seneca-password"
            ]
        && !(absent.networking.networkmanager.ensureProfiles.profiles ? SenecaNET)
        && lib.any (lib.hasInfix "SenecaNET is not provisioned while null") absent.fleet.bootstrap.missing
      )
      "Wi-Fi must retain root-only runtime secrets, PEAP certificate/name validation and missing-campus-credential blocking.";
    {
      runtimeSecrets = true;
      campusCertificateValidation = true;
      missingCampusCredentialsBlocked = true;
    };
  deploymentPkgs = pkgs: pkgs.extend inputs.deploy-rs.overlays.default;
  fixtureReport = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      bios = (fixtureFor track "bios" allCapabilities).config;
      unconfirmed = fixture.extendModules {
        modules = [ { fleet.osDisk.confirmed = lib.mkForce false; } ];
      };
      partition = fixture.extendModules {
        modules = [ { fleet.osDisk.device = lib.mkForce "/dev/disk/by-id/TEST-ONLY-part1"; } ];
      };
      blank = fixture.extendModules {
        modules = [ { fleet.osDisk.device = lib.mkForce null; } ];
      };
      withEspSize =
        espSize:
        (fixture.extendModules {
          modules = [ { fleet.osDisk.espSize = lib.mkForce espSize; } ];
        }).config;
      missingEsp = withEspSize null;
      espSizes = {
        accepted = [
          "512M"
          "513M"
          "1024M"
          "1G"
          "2G"
        ];
        rejected = [
          "1M"
          "511M"
          "0M"
          "0G"
          "512"
          "512MB"
          "512MiB"
          "512m"
          "1.5G"
        ];
      };
      # Reuse the actual host metadata type and its deferred deployment module.
      # These hosts exist only in this isolated evaluation, never in fleet/deploy outputs.
      deploymentFor =
        sshUser:
        let
          host =
            (lib.evalModules {
              modules = [
                {
                  options.hosts = lib.mkOption { type = options.fleet.hosts.type; };
                  config.hosts.fixture = {
                    system = "x86_64-linux";
                    inherit track;
                    deployment = {
                      enable = true;
                      hostname = "evaluation-only.test";
                      transport = "trusted-user";
                      inherit sshUser;
                    };
                  };
                }
              ];
            }).config.hosts.fixture;
        in
        assert lib.assertMsg (
          host.deployment.profileUser == "root"
        ) "${track}: system activation must still default to root";
        fixture.extendModules { modules = [ host.module ]; };
      deployAdmin = deploymentFor "fixture-admin";
      deployRoot = (deploymentFor "root").extendModules {
        modules = [ { users.users.root.openssh.authorizedKeys.keys = cfg.fleet.access.authorizedKeys; } ];
      };
      deployNull = deploymentFor null;
      deployUnknown = deploymentFor "fixture-missing";
      failedAssertions =
        system: map (a: a.message) (lib.filter (a: !a.assertion) system.config.assertions);
      deployLib = (deploymentPkgs fixture.pkgs).deploy-rs.lib;
    in
    assert lib.assertMsg (cfg.fleet.bootstrap.missing == [ ]) "${track}: fixture requirements missing";
    assert lib.assertMsg (lib.all (a: a.assertion) cfg.assertions)
      "${track}: ${
        lib.concatStringsSep "; " (map (a: a.message) (lib.filter (a: !a.assertion) cfg.assertions))
      }";
    assert lib.assertMsg (
      cfg.fileSystems."/".fsType == "tmpfs"
      && cfg.fileSystems."/persist".neededForBoot
      && cfg.fileSystems."/nix".neededForBoot
    ) "${track}: ephemeral-root/early persistent mounts regressed";
    assert lib.assertMsg (
      !(builtins.tryEval unconfirmed.config.disko.devices.disk.os.device).success
    ) "Unconfirmed disko device was accepted";
    assert lib.assertMsg (
      !(builtins.tryEval partition.config.disko.devices.disk.os.device).success
    ) "Partition accepted as whole OS disk";
    assert lib.assertMsg (
      blank.config.disko.devices.disk == { }
    ) "Missing device must produce no destructive disk configuration";
    # Force the actual script derivation, not just the declared option type:
    # NixOS toplevel assertions alone do not guard direct disko evaluation.
    assert lib.all (
      size:
      lib.assertMsg (
        !(builtins.tryEval (withEspSize size).system.build.diskoScript.drvPath).success
      ) "${track}: invalid/undersized ESP '${size}' allowed a disko script"
    ) espSizes.rejected;
    assert lib.all (
      size:
      let
        sized = withEspSize size;
      in
      lib.assertMsg (
        sized.disko.devices.disk.os.content.partitions.ESP.size == size
        && sized.fleet.bootstrap.missing == [ ]
        && builtins.isString sized.system.build.diskoScript.drvPath
      ) "${track}: valid ESP '${size}' was rejected or altered"
    ) espSizes.accepted;
    assert lib.assertMsg (
      missingEsp.fleet.osDisk.espSize == null
      && missingEsp.disko.devices.disk == { }
      && lib.elem "Size fleet.osDisk.espSize explicitly." missingEsp.fleet.bootstrap.missing
    ) "${track}: missing ESP size must remain a blocker with no destructive disk configuration";
    assert lib.assertMsg (
      bios.fleet.osDisk.espSize == null
      && !(bios.disko.devices.disk.os.content.partitions ? ESP)
      && bios.fleet.bootstrap.missing == [ ]
    ) "${track}: BIOS must not require or create an ESP";
    assert lib.assertMsg (lib.all
      (system: system.config.services.openssh.settings.PermitRootLogin == "no")
      [
        deployAdmin
        deployRoot
        deployNull
      ]
    ) "${track}: deployment must not relax the SSH root-login policy";
    assert lib.assertMsg (
      deployAdmin.config.fleet.bootstrap.missing == [ ] && failedAssertions deployAdmin == [ ]
    ) "${track}: keyed non-root deployment user was rejected";
    assert lib.assertMsg (
      deployRoot.config.fleet.bootstrap.missing == [ ]
      &&
        failedAssertions deployRoot == [
          "Deployment SSH user must be non-root; SSH root login is disabled."
        ]
      && !(builtins.tryEval deployRoot.config.system.build.toplevel.drvPath).success
    ) "${track}: root deployment SSH user with a public key must fail readiness/toplevel evaluation";
    assert lib.assertMsg (
      deployNull.config.fleet.bootstrap.missing == [ "Supply deployment.sshUser and verify elevation." ]
      && !(builtins.tryEval deployNull.config.system.build.toplevel.drvPath).success
    ) "${track}: missing deployment SSH user must remain a commissioning blocker";
    assert lib.assertMsg (
      failedAssertions deployUnknown == [
        "Deployment SSH user must have an explicitly configured account and public keys."
      ]
      && !(builtins.tryEval deployUnknown.config.system.build.toplevel.drvPath).success
    ) "${track}: deployment must still reject an unconfigured SSH account";
    {
      inherit espSizes;
      deploymentAccess = {
        nonRootToplevel = deployAdmin.config.system.build.toplevel.drvPath;
        rootRejected = true;
        nullBlocked = true;
        unknownUserRejected = true;
      };
      toplevel = cfg.system.build.toplevel.drvPath;
      biosToplevel = bios.system.build.toplevel.drvPath;
      activation = (deployLib.activate.nixos fixture).drvPath;
      diskScript = cfg.system.build.diskoScript.drvPath;
      inherit (cfg.fleet.bootstrap) missing;
    }
  ) fixtures;
in
{
  flake.validation = {
    hosts = checkedReport;
    fixtures = fixtureReport;
    compositions = compositionReport;
    existingInstallations = existingReport;
    sops = sopsReport;
    desktop = desktopReport;
    wifi = wifiReport;
  };
  perSystem = { pkgs, ... }: {
    checks = {
      # Evaluate drvPaths but do not turn their deep string contexts into build
      # dependencies. This report is data, never executable or an installation input.
      fleet-evaluation = pkgs.writeText "fleet-evaluation.json" (
        builtins.unsafeDiscardStringContext (
          builtins.toJSON {
            hosts = checkedReport;
            fixtures = fixtureReport;
            compositions = compositionReport;
            existingInstallations = existingReport;
            sops = sopsReport;
            desktop = desktopReport;
            wifi = wifiReport;
          }
        )
      );
      wifi-secret-environment = pkgs.runCommand "wifi-secret-environment" { } ''
        ${lib.getExe pkgs.python3} ${./desktop/assets/test-wifi-environment.py} \
          ${./desktop/assets/wifi-environment.py} ${lib.getLib pkgs.glib}/lib/libglib-2.0.so ${lib.getExe pkgs.envsubst}
        touch "$out"
      '';
      # Parse actual declared home/campus ciphertext keys, never decrypt them.
      thinkpad-wifi-manifest =
        config.flake.fleetConfigurations.thinkpad.config.system.build.sops-nix-manifest;
      # Key selection can pass on markers; no decryption or credential acceptance.
      senecanet-template-manifest = senecaTemplate.system.build.sops-nix-manifest;
      thinkpad-desktop-config =
        desktopConfigCheck "thinkpad" config.flake.fleetConfigurations.thinkpad
          "marcos";
    }
    // lib.mapAttrs' (
      track: fixture:
      lib.nameValuePair "${track}-desktop-config" (desktopConfigCheck track fixture "fixture-admin")
    ) desktopFixtures
    // lib.mapAttrs' (
      track: fixture:
      lib.nameValuePair "${track}-sops-users-manifest" fixture.config.system.build.sops-nix-users-manifest
    ) fixtures
    // lib.concatMapAttrs (
      track: fixture:
      let
        deployLib = (deploymentPkgs fixture.pkgs).deploy-rs.lib;
        # Exercise real upstream activation checks on tiny, non-system payloads.
        # The real NixOS activation derivations are evaluated separately above.
        smoke = deployLib.deployChecks {
          nodes.fixture = {
            hostname = "evaluation-only.invalid";
            profiles.smoke = {
              user = "root";
              path = deployLib.activate.custom (fixture.pkgs.runCommand "smoke-payload" { }
                ''mkdir -p "$out"''
              ) ":";
            };
          };
        };
      in
      lib.mapAttrs' (name: value: lib.nameValuePair "${track}-${name}-smoke" value) smoke
    ) fixtures;
  };
}
