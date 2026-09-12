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
      "agents"
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
    # Temporary workstation for the final ThinkPad reinstall: ordinary marcos,
    # no new account/role, no desktop, and no credential copying or enrollment.
    module = { config, pkgs, ... }: {
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
      # Agent-only workspace: removing editors must not restore default nano.
      programs.nano.enable = false;
      environment.systemPackages = [
        pkgs.tmux
        pkgs.devenv
      ];
      environment.persistence."/persist".directories = [
        {
          directory = config.users.users.marcos.home;
          user = "marcos";
          inherit (config.users.users.marcos) group;
          mode = "0700";
        }
      ];
    };
  };

  fleet.validation.hostChecks.bastionTools =
    {
      name,
      system,
      ...
    }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg
      (
        name != "bastion"
        || (
          lib.all (p: lib.elem p cfg.environment.systemPackages) (
            with system.pkgs;
            [
              pi-coding-agent
              git
              gh
              tmux
              devenv
            ]
          )
          && !(cfg ? home-manager)
          && !cfg.programs.neovim.enable
          && !cfg.programs.nano.enable
          && config.fleet.hosts.${name}.deployment.transport == "signed"
          && !(lib.elem "marcos" cfg.nix.settings.trusted-users)
          && !(lib.elem "@wheel" cfg.nix.settings.trusted-users)
          && cfg.nix.settings.require-sigs
          && lib.elem "bastion-deploy-20260912:FYekV+z8HC3dmaBay30ThuDpgGWrWoLolsSRNs+2dJs=" cfg.nix.settings.trusted-public-keys
          && !cfg.networking.networkmanager.enable
          && cfg.users.users.marcos.isNormalUser
          && lib.any (
            d: d.dirPath == "/home/marcos" && d.user == "marcos" && d.mode == "0700"
          ) cfg.environment.persistence."/persist".directories
          && cfg.fileSystems."/persist".fsType == "btrfs"
        )
      )
      "Bastion's temporary Pi workspace must use its normal admin, private OS persistence and own-track tools";
    true;

}
