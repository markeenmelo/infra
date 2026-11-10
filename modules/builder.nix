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
  builderKeys = {
    mac = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINoA+orfMja/cji7njutAe9r4c4xe3w5j0iCRzp+tYwE";
    thinkpad = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEDFHuli2Hq2SXHpI0ssAe+F/No0lEGfGXnh/0F3hEsf";
    asahi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILIb4eAjq8vyvDQuSkigT359wRoqU+pfVfny1OKl0oN2";
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
    let
      push = pkgs.writeShellScript "push-to-bastion" ''
        set -f
        failed=/var/run/nix-push-to-bastion-failed
        if [ -n "$(find "$failed" -mmin -10 2>/dev/null)" ]; then exit 0; fi
        NIX_SSHOPTS="-o ConnectTimeout=3 -o ServerAliveInterval=5 -o ServerAliveCountMax=2" ${lib.getExe config.nix.package} copy --substitute-on-destination \
          --to "ssh-ng://nix-ssh@${bastion}?ssh-key=${config.sops.secrets.nix-build-ssh-key.path}" $OUT_PATHS \
          || touch "$failed"
      '';
    in
    {
      imports = [ cacheClient ];
      sops.secrets.nix-build-ssh-key = { };
      programs.ssh.knownHosts.bastion = {
        hostNames = [ bastion ];
        publicKey = hostKey;
      };
      nix = {
        distributedBuilds = true;
        settings = {
          builders-use-substitutes = true;
          post-build-hook = push;
        };
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
in
{
  flake.modules.nixos.builder =
    { config, ... }:
    {
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
      # shortcut: garbage collection waits for under 20 GiB free, so any unrooted closure can still go then; root each host's deployed closure if CI or deploys start missing it
      programs.nh.clean.extraArgs = "--keep 10 --keep-since 14d --no-gc";
      nix.settings = {
        min-free = 20 * 1024 * 1024 * 1024;
        max-free = 40 * 1024 * 1024 * 1024;
      };
    };

  flake.modules.nixos.cache = cacheClient;

  flake.modules.darwin.remote-builds = remoteBuilds;

  flake.modules.nixos.remote-builds =
    { lib, pkgs, ... }:
    {
      imports = [ remoteBuilds ];
      nix.settings.max-jobs = lib.mkIf (pkgs.stdenv.hostPlatform.system == hosts.bastion.system) 0;
    };
}
