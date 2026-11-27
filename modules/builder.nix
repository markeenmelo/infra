{ config, lib, ... }:
let
  inherit (config.fleet) hosts;
  bastion = hosts.bastion.tailnetAddress;
  port = config.fleet.cachePort;
  # public half of harmonia-sign-key in secrets/hosts/bastion.yaml
  cacheKey = "bastion-cache-1:KdPVnZyY7c8KxpwJ4V5xNwuQmfdiu8CN3XJ9g3+ecZQ=";
  builders = {
    bastion = {
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICMInx05Ck0g1CMi7PlOOxABh/o8rDFnZAJxNXwPgiih";
      maxJobs = 2;
      speedFactor = 1;
    };
    beast = {
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPXndlFVNQh7GH5OHUsoavMfPSxq5Z65/3zKkqcEPsSR";
      maxJobs = 4;
      speedFactor = 2;
    };
  };
  # the key each admin client's nix daemon presents to the builders; private half is nix-build-ssh-key
  builderKeys = {
    thinkpad = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEDFHuli2Hq2SXHpI0ssAe+F/No0lEGfGXnh/0F3hEsf";
  };
  cacheClient.nix.settings = {
    substituters = [ "http://${bastion}:${toString port}" ];
    trusted-public-keys = [ cacheKey ];
  };
  remoteBuilds =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ cacheClient ];
      sops.secrets.nix-build-ssh-key = { };
      programs.ssh.knownHosts = lib.mapAttrs (name: builder: {
        hostNames = [ hosts.${name}.tailnetAddress ];
        publicKey = builder.hostKey;
      }) builders;
      nix = {
        distributedBuilds = true;
        settings = {
          builders-use-substitutes = true;
        };
        buildMachines = lib.mapAttrsToList (name: builder: {
          hostName = hosts.${name}.tailnetAddress;
          protocol = "ssh-ng";
          sshUser = "nix-ssh";
          sshKey = config.sops.secrets.nix-build-ssh-key.path;
          systems = [
            hosts.${name}.system
            "i686-linux"
          ];
          inherit (builder) maxJobs speedFactor;
          supportedFeatures = [
            "big-parallel"
            "kvm"
            "nixos-test"
          ];
        }) builders;
      };
    };
  buildHost = {
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
in
{
  options.fleet.cachePort = lib.mkOption {
    type = lib.types.port;
    description = "Port on bastion's tailnet address where Harmonia serves the binary cache; the `tofu` app hands it to `opentofu/tailscale` as `fleet_cache_port`.";
  };
  config.fleet.cachePort = 5005;

  config.flake.modules.nixos.build-host = buildHost;

  config.flake.modules.nixos.builder =
    { config, ... }:
    {
      imports = [ buildHost ];
      sops.secrets.harmonia-sign-key.restartUnits = [ "harmonia.service" ];
      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [ config.sops.secrets.harmonia-sign-key.path ];
        settings.bind = "${bastion}:${toString port}";
      };
      systemd.sockets.harmonia.socketConfig.FreeBind = true;
      networking.firewall.extraInputRules = ''
        iifname "${config.services.tailscale.interfaceName}" tcp dport ${toString port} accept
      '';
      # shortcut: garbage collection waits for under 20 GiB free, so any unrooted closure can still go then; root each host's deployed closure if CI or deploys start missing it
      nix.gc.automatic = false;
      nix.settings = {
        min-free = 20 * 1024 * 1024 * 1024;
        max-free = 40 * 1024 * 1024 * 1024;
      };
    };

  config.flake.modules.nixos.cache-client = cacheClient;

  config.flake.modules.nixos.remote-builds =
    { lib, pkgs, ... }:
    {
      imports = [ remoteBuilds ];
      nix.settings.max-jobs = lib.mkIf (pkgs.stdenv.hostPlatform.system == hosts.bastion.system) 0;
    };
}
