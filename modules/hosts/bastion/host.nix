{ config, lib, ... }:
let
  bastion = config.flake.fleetConfigurations.bastion;
in
{
  fleet.hosts.bastion = {
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "bastion-disko"
      "headless"
      "persistence"
      "access"
      "server"
      "nas"
      "editors"
    ];
    deployment = {
      enable = true;
      hostname = "192.168.2.2";
      sshUser = "marcos";
    };
    # Temporary workstation for the final ThinkPad reinstall: ordinary marcos,
    # no new account/role, no desktop, and no credential copying or enrollment.
    module = { config, pkgs, ... }: {
      environment.systemPackages = [
        pkgs.pi-coding-agent
        pkgs.git
        pkgs.tmux
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
    { name, system, ... }:
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
              tmux
            ]
          )
          && !(cfg ? home-manager)
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

  perSystem = { pkgs, ... }: {
    checks.bastion-pi = pkgs.runCommand "bastion-pi" { } ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      # This pin redirects stdout to stderr without a TTY, even for --version.
      version=$(env -i HOME="$HOME" PATH=${bastion.pkgs.coreutils}/bin ${bastion.pkgs.pi-coding-agent}/bin/pi --version 2>&1)
      test "$version" = '${bastion.pkgs.pi-coding-agent.version}'
      touch "$out"
    '';
  };
}
