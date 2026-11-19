{ config, inputs, ... }:
let
  inherit (config.flake.modules.nixos) nixflix;
  inherit (import ./_downloads.nix)
    tap
    hostAddress
    guestAddress
    mac
    ;
  stateOf = [
    "sonarr"
    "radarr"
    "prowlarr"
    "qbittorrent"
    "sabnzbd"
  ];

  guest = {
    system.stateVersion = "26.05";

    microvm = {
      hypervisor = "cloud-hypervisor";
      vcpu = 4;
      mem = 8192;
      volumes = [
        {
          image = "var.img";
          label = "var";
          mountPoint = "/var/lib";
          size = 16 * 1024;
        }
      ];
      interfaces = [
        {
          type = "tap";
          id = tap;
          inherit mac;
        }
      ];
    };

    networking = {
      useDHCP = false;
      # the tailnet's global resolvers, as in opentofu/tailscale
      nameservers = [
        "76.76.2.2"
        "76.76.10.2"
      ];
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

    fileSystems."/var/lib".neededForBoot = true;

    services.journald.settings.Journal.ForwardToConsole = true;
    users = {
      mutableUsers = false;
      allowNoPasswordLogin = true;
    };
  };
in
{
  flake.modules.nixos.downloads =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.microvm) stateDir;

      media = dirOf config.nixflix.mediaDir;
      shared = [ media ] ++ map (name: "${config.nixflix.stateDir}/${name}") stateOf;
      hostOptions = mount: lib.remove "nofail" config.fileSystems.${mount}.options;
    in
    {
      imports = [
        inputs.microvm.nixosModules.host
        nixflix
      ];

      microvm = {
        host.installCommand = false;
        vms.downloads.config = {
          imports = [ guest ];
          microvm.shares = map (path: {
            proto = "virtiofs";
            tag = baseNameOf path;
            source = path;
            mountPoint = path;
          }) shared;
          fileSystems = lib.genAttrs shared (path: {
            options = hostOptions (if path == media then media else config.nixflix.stateDir);
          });
        };
      };
      hardware.ksm.enable = false;
      security.wrappers.qemu-bridge-helper.enable = false;

      boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = lib.mkDefault true;
      systemd.network.networks."20-downloads" = {
        matchConfig.Name = tap;
        address = [ "${hostAddress}/24" ];
        networkConfig = {
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };
      networking.nftables.tables.downloads = {
        family = "inet";
        content = ''
          chain input {
            type filter hook input priority -10; policy accept;
            iifname "${tap}" ct state established,related accept
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
        downloads-state = {
          description = "Create the downloads MicroVM's state directory on its dataset";
          requiredBy = [ "install-microvm-downloads.service" ];
          before = [ "install-microvm-downloads.service" ];
          unitConfig.RequiresMountsFor = stateDir;
          restartIfChanged = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${lib.getExe' config.systemd.package "systemd-tmpfiles"} --create --prefix=${stateDir}/downloads";
          };
        };
        "microvm-virtiofsd@downloads" = {
          unitConfig.RequiresMountsFor = shared;
          serviceConfig.ExecStartPre = [
            "${lib.getExe' pkgs.coreutils "mkdir"} -p ${lib.concatStringsSep " " shared}"
          ];
        };
        "microvm@downloads" = {
          requires = [
            "install-microvm-downloads.service"
            "nftables.service"
          ];
          after = [ "nftables.service" ];
          serviceConfig.UMask = "0077";
        };
      };
    };
}
