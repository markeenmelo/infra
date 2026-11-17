{ inputs, ... }:
let
  # the operator's login key, the one access.nix admits on the laptops
  operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYdnogT40vOG0eZn4guvWq33q6VANCYXEYsxOSIsVbc";
  tap = "vm-agents";
  hostAddress = "10.201.0.1";
  guestAddress = "10.201.0.2";
  mac = "02:00:00:00:00:01";
  hostSecrets = "/run/agents-secrets";
  guestSecrets = "/run/host-secrets";
  storeImage = "store.img";

  guest =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      zedServer = "zed-remote-server-stable-${pkgs.zed-editor.version}";
    in
    {
      system.stateVersion = "26.05";

      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = 4;
        mem = 8192;
        interfaces = [
          {
            type = "tap";
            id = tap;
            inherit mac;
          }
        ];
        shares = [
          {
            proto = "virtiofs";
            tag = "secrets";
            source = hostSecrets;
            mountPoint = guestSecrets;
            readOnly = true;
          }
        ];
        writableStoreOverlay = "/nix/.rw-store";
        volumes = [
          {
            image = storeImage;
            label = "store";
            mountPoint = config.microvm.writableStoreOverlay;
            size = 32 * 1024;
          }
          {
            image = "state.img";
            label = "state";
            mountPoint = "/var/lib";
            size = 1024;
          }
          {
            image = "home.img";
            label = "home";
            mountPoint = "/home";
            size = 16 * 1024;
          }
        ];
      };
      fileSystems = lib.genAttrs [ "/var/lib" "/home" ] (_: {
        neededForBoot = true;
      });

      networking = {
        useDHCP = false;
        # the tailnet's global resolvers, as in opentofu/tailscale
        nameservers = [
          "76.76.2.2"
          "76.76.10.2"
        ];
        firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
          config.services.openssh.ports;
      };
      systemd.network.networks."10-uplink" = {
        matchConfig.MACAddress = mac;
        address = [ "${guestAddress}/24" ];
        gateway = [ hostAddress ];
        networkConfig = {
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
      };

      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = "${guestSecrets}/tailscale-auth-key";
        disableTaildrop = true;
        extraUpFlags = [
          "--reset"
          "--accept-dns=false"
        ];
      };
      systemd.services.tailscaled-autoconnect.unitConfig.RequiresMountsFor = guestSecrets;

      services.openssh = {
        enable = true;
        openFirewall = false;
        authorizedKeysInHomedir = false;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = [ "agent" ];
        };
        hostKeys = [
          {
            path = "/var/lib/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };

      users = {
        mutableUsers = false;
        allowNoPasswordLogin = true;
        users.agent = {
          isNormalUser = true;
          uid = 1000;
          openssh.authorizedKeys.keys = [ operatorKey ];
        };
      };

      nix = {
        channel.enable = false;
        settings.experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
      environment.systemPackages = [
        pkgs.claude-code
        pkgs.git
        pkgs.gh
        pkgs.tmux
        pkgs.ripgrep
      ];
      systemd.tmpfiles.rules = [
        "d /home/agent/.zed_server 0755 agent users -"
        "L+ /home/agent/.zed_server/${zedServer} - - - - ${lib.getExe' pkgs.zed-editor.remote_server zedServer}"
      ];
    };
in
{
  flake.modules.homeManager.base.programs.zed-editor.userSettings.ssh_connections = [
    {
      host = "agents";
      username = "agent";
      projects = [ ];
    }
  ];

  flake.modules.nixos.agents =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.microvm) stateDir;
    in
    {
      imports = [ inputs.microvm.nixosModules.host ];

      nixpkgs.config.allowUnfreePackages = [ "claude-code" ];
      microvm = {
        host.installCommand = false;
        vms.agents.config = guest;
      };
      hardware.ksm.enable = false;
      security.wrappers.qemu-bridge-helper.enable = false;

      sops.secrets.agents-tailscale-auth-key = {
        key = "agents/tailscale-auth-key";
        restartUnits = [ "microvm@agents.service" ];
      };

      boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = lib.mkDefault true;
      systemd.network.networks."20-agents" = {
        matchConfig.Name = tap;
        address = [ "${hostAddress}/24" ];
        networkConfig = {
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };
      networking.nftables.tables.agents = {
        family = "inet";
        content = ''
          chain input {
            type filter hook input priority -10; policy accept;
            iifname "${tap}" drop
          }
          chain forward {
            type filter hook forward priority -10; policy accept;
            iifname "${tap}" meta nfproto ipv6 drop
            iifname "${tap}" ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/3 } drop
            iifname "${tap}" oifname "${config.services.tailscale.interfaceName}" drop
          }
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            iifname "${tap}" masquerade
          }
        '';
      };

      systemd.services = {
        agents-state = {
          description = "Create the agent MicroVM's state directory on its dataset";
          requiredBy = [ "install-microvm-agents.service" ];
          before = [ "install-microvm-agents.service" ];
          unitConfig.RequiresMountsFor = stateDir;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${lib.getExe' config.systemd.package "systemd-tmpfiles"} --create --prefix=${stateDir}";
          };
        };
        "microvm-virtiofsd@agents".serviceConfig.ExecStartPre =
          "${lib.getExe' pkgs.coreutils "install"} -m 0400 ${config.sops.secrets.agents-tailscale-auth-key.path} ${hostSecrets}/tailscale-auth-key";
        "microvm@agents".serviceConfig = {
          UMask = "0077";
          ExecStartPre = "${lib.getExe' pkgs.coreutils "rm"} -f ${storeImage}";
        };
      };
    };
}
