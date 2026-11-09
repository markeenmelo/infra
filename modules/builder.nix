{ config, lib, ... }:
let
  inherit (config.fleet) hosts;
  bastion = hosts.bastion.tailnetAddress;
  port = 5005;
  # public half of harmonia-sign-key in secrets/hosts/bastion.yaml
  cacheKey = "bastion-cache-1:KdPVnZyY7c8KxpwJ4V5xNwuQmfdiu8CN3XJ9g3+ecZQ=";
  # bastion's SSH host key
  hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMInx05Ck0g1CMi7PlOOxABh/o8rDFnZAJxNXwPgiih";
  # the key each admin client's nix daemon presents to bastion's builder; private half is nix-build-ssh-key
  builderKeys.mac = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINoA+orfMja/cji7njutAe9r4c4xe3w5j0iCRzp+tYwE";
in
{
  flake.modules.nixos.builder =
    { config, ... }:
    {
      sops.secrets.harmonia-sign-key = {
        sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
        restartUnits = [ "harmonia.service" ];
      };
      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [ config.sops.secrets.harmonia-sign-key.path ];
        settings.bind = "${bastion}:${toString port}";
      };
      systemd.sockets.harmonia.socketConfig.FreeBind = true;
      networking.firewall.extraInputRules = ''
        iifname "${config.services.tailscale.interfaceName}" ip saddr ${hosts.racknerd.tailnetAddress} tcp dport ${toString port} accept
      '';
      nix.sshServe = {
        enable = true;
        protocol = "ssh-ng";
        write = true;
        trusted = true;
        keys = lib.mapAttrsToList (
          name: key: ''restrict,from="${hosts.${name}.tailnetAddress}" ${key}''
        ) builderKeys;
      };
      services.openssh.settings.AllowUsers = [ "nix-ssh" ];
    };

  flake.modules.nixos.cache.nix.settings = {
    substituters = [ "http://${bastion}:${toString port}" ];
    trusted-public-keys = [ cacheKey ];
  };

  flake.modules.darwin.remote-builds =
    { config, ... }:
    {
      sops.secrets.nix-build-ssh-key.sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
      programs.ssh.knownHosts.bastion = {
        hostNames = [ bastion ];
        publicKey = hostKey;
      };
      nix = {
        distributedBuilds = true;
        settings.builders-use-substitutes = true;
        buildMachines = [
          {
            hostName = bastion;
            protocol = "ssh-ng";
            sshUser = "nix-ssh";
            sshKey = config.sops.secrets.nix-build-ssh-key.path;
            systems = [ hosts.bastion.system ];
            maxJobs = 2;
            supportedFeatures = [
              "big-parallel"
              "kvm"
              "nixos-test"
            ];
          }
        ];
      };
    };
}
