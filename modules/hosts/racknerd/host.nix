{ config, lib, ... }:
{
  fleet.hosts.racknerd = {
    ready = true;
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "racknerd-disko"
      "headless"
      "persistence"
      "access"
      "server"
      "vps"
    ];
    deployment = {
      enable = true;
      hostname = "72.11.150.242";
      sshUser = "marcos";
      transport = "signed";
      sshOpts = [
        "-o"
        "StrictHostKeyChecking=yes"
      ];
    };
    module.nix.settings.trusted-public-keys = [
      "racknerd-deploy-20260912:dJ7er88VXs6+ZiVlGu1LTnlXc+EujXsqdVYb3Grh2Ak="
    ];
  };

  fleet.validation.hostChecks.racknerdAccess =
    { name, system, ... }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg (
      name != "racknerd"
      || (
        config.fleet.hosts.${name}.deployment.transport == "signed"
        && cfg.nix.settings.trusted-users == [ "root" ]
        && cfg.nix.settings.require-sigs
        && lib.elem "racknerd-deploy-20260912:dJ7er88VXs6+ZiVlGu1LTnlXc+EujXsqdVYb3Grh2Ak=" cfg.nix.settings.trusted-public-keys
        && !cfg.users.mutableUsers
        && cfg.security.sudo.wheelNeedsPassword
        && !cfg.fleet.access.passwordlessSudo
        && cfg.services.openssh.settings.PermitRootLogin == "no"
        && cfg.services.fail2ban.enable
        && !(cfg ? home-manager)
      )
    ) "Racknerd must retain signed/root-only Nix trust, strict SSH and password sudo";
    true;
}
