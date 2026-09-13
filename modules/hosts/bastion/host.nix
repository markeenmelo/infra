{ config, lib, ... }:
{
  fleet.hosts.bastion = {
    system = "x86_64-linux";
    track = "stable";
    # Pre-install commissioning facts reviewed 2026-09-12; boot acceptance is
    # separately recorded in docs/hosts.md. No Racknerd/ThinkPad approval.
    ready = true;
    capabilities = [
      "bastion-disko"
      "headless"
      "persistence"
      "access"
      "server"
      "nas"
    ];
    deployment = {
      enable = true;
      hostname = "192.168.2.2";
      sshUser = "marcos";
      transport = "signed";
      sshOpts = [
        "-o"
        "StrictHostKeyChecking=yes"
      ];
    };
    # Server-only baseline; administration and deployment live off-host.
    module = {
      # Live-USB preflight 2026-09-12: verified DHCP MAC/routes/console without VPN.
      fleet.installation.networkReviewed = true;
      fleet.secrets = {
        ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
        ageRecipient = "age1su25ytldd4uye705w6jllwzkmpdkprruq5mzpcrth0e9zcmcyewspeck6q";
        # Protected recovery plus actual root-only early-delivery RAMFS rehearsal.
        identityReviewed = true;
      };
      # Public closure trust only. The operator's signing identity stays off-host.
      nix.settings.trusted-public-keys = [
        "bastion-deploy-20260912:FYekV+z8HC3dmaBay30ThuDpgGWrWoLolsSRNs+2dJs="
      ];
    };
  };

  fleet.validation.hostChecks.bastionAccess =
    {
      name,
      system,
      ...
    }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg (
      name != "bastion"
      || (
        config.fleet.hosts.${name}.deployment.transport == "signed"
        && !(lib.elem "marcos" cfg.nix.settings.trusted-users)
        && !(lib.elem "@wheel" cfg.nix.settings.trusted-users)
        && cfg.nix.settings.require-sigs
        && lib.elem "bastion-deploy-20260912:FYekV+z8HC3dmaBay30ThuDpgGWrWoLolsSRNs+2dJs=" cfg.nix.settings.trusted-public-keys
        && !cfg.networking.networkmanager.enable
        && cfg.users.users.marcos.isNormalUser
        && cfg.fileSystems."/persist".fsType == "btrfs"
      )
    ) "Bastion must retain its normal admin, signed closure trust and OS persistence";
    true;

}
