{ config, ... }:
{
  fleet.hosts.bastion.tailnetAddress = "100.105.158.109";
  fleet.hosts.bastion.lan = {
    address = "192.168.2.2";
    gateway = "192.168.2.1";
    mac = "6c:1f:f7:56:0a:10";
    syslogPort = 5514;
    routes = {
      homelab = "192.168.2.0/24";
      iot = "192.168.4.0/24";
      kids = "192.168.20.0/24";
    };
  };
  fleet.hosts.bastion.module = {
    imports = with config.flake.modules.nixos; [
      server
      lan-proxy
      authelia
      immich
      frigate
      opencloud
      jellyfin
      arr
      backups
      builder
      opentofu-state
      proton-exit
      monitoring
    ];
    system.stateVersion = "26.05";
  };
}
