inputs:
{
  name,
  tap,
  hostAddress,
  guestAddress,
  mac,
  cid,
}:
{
  guest = {
    system.stateVersion = "26.05";

    microvm = {
      hypervisor = "cloud-hypervisor";
      vsock.cid = cid;
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

    services.journald.settings.Journal.ForwardToConsole = true;
    users = {
      mutableUsers = false;
      allowNoPasswordLogin = true;
    };
  };

  host =
    { config, lib, ... }:
    let
      inherit (config.microvm) stateDir;
    in
    {
      imports = [ inputs.microvm.nixosModules.host ];

      microvm.host.installCommand = false;
      hardware.ksm.enable = false;
      security.wrappers.qemu-bridge-helper.enable = false;

      boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = lib.mkDefault true;
      systemd.network.networks."20-${name}" = {
        matchConfig.Name = tap;
        address = [ "${hostAddress}/24" ];
        networkConfig = {
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "no";
      };
      networking.nftables.tables.${name} = {
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
            oifname "${tap}" ct state new drop
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
        "${name}-state" = {
          description = "Create the ${name} MicroVM's state directory on its dataset";
          requiredBy = [ "install-microvm-${name}.service" ];
          before = [ "install-microvm-${name}.service" ];
          unitConfig.RequiresMountsFor = stateDir;
          restartIfChanged = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${lib.getExe' config.systemd.package "systemd-tmpfiles"} --create --prefix=${stateDir}/${name}";
          };
        };
        "microvm@${name}" = {
          requires = [
            "install-microvm-${name}.service"
            "nftables.service"
          ];
          after = [ "nftables.service" ];
          serviceConfig.UMask = "0077";
        };
      };
    };
}
