{
  config,
  inputs,
  lib,
  ...
}:
let
  nodes = {
    racknerd.hostname = "72.11.150.242";
    bastion.hostname = "192.168.2.2";
  };
in
{
  fleet.hosts = lib.mapAttrs (_: _: {
    module =
      { config, pkgs, ... }:
      {
        users.groups.deploy = { };
        users.users.deploy = {
          isSystemUser = true;
          group = "deploy";
          extraGroups = [ "wheel" ];
          home = "/var/lib/deploy";
          createHome = true;
          homeMode = "700";
          shell = pkgs.bash;
          hashedPassword = "!";
          openssh.authorizedKeys.keys = map (key: "restrict ${key}") config.fleet.access.authorizedKeys;
        };
        security.sudo.extraRules = [
          {
            users = [ "deploy" ];
            runAs = "root";
            commands =
              map
                (command: {
                  inherit command;
                  options = [ "NOPASSWD" ];
                })
                [
                  "/nix/store/*-activatable-nixos-system-*/activate-rs"
                  "/run/current-system/sw/bin/systemctl reboot"
                  "${pkgs.coreutils-full}/bin/rm ^/run/deploy-rs/deploy-rs-canary-[0-9abcdfghijklmnpqrsvwxyz]{32}$"
                ];
          }
        ];
        nix.settings = {
          trusted-users = [ "deploy" ];
          build-dir = "/nix/var/nix/builds";
        };
        systemd.tmpfiles.rules = [
          "d /run/deploy-rs 0700 root root -"
          "d /nix/var/nix/builds 0700 root root -"
        ];
      };
  }) nodes;

  flake.deploy.nodes = lib.mapAttrs (
    name: node:
    let
      nixos = config.flake.nixosConfigurations.${name};
    in
    {
      inherit (node) hostname;
      sshUser = "deploy";
      sudo = "sudo -n -u";
      remoteBuild = true;
      autoRollback = true;
      magicRollback = true;
      activationTimeout = 300;
      confirmTimeout = 60;
      tempPath = "/run/deploy-rs";
      sshOpts = [
        "-o"
        "BatchMode=yes"
        "-o"
        "StrictHostKeyChecking=yes"
        "-o"
        "UpdateHostKeys=no"
        "-o"
        "IdentityAgent=none"
        "-o"
        "IdentitiesOnly=yes"
        "-o"
        "ForwardAgent=no"
        "-o"
        "ClearAllForwardings=yes"
        "-o"
        "ConnectTimeout=15"
        "-o"
        "ServerAliveInterval=10"
        "-o"
        "ServerAliveCountMax=3"
      ];
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.${nixos.pkgs.stdenv.hostPlatform.system}.activate.nixos nixos;
      };
    }
  ) nodes;

  perSystem =
    { system, ... }:
    {
      packages.deploy-rs = inputs.deploy-rs.packages.${system}.default;
    };
}
