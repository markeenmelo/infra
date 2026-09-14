{ lib, ... }:
{
  fleet.hosts = lib.genAttrs [ "bastion" "racknerd" ] (_: {
    module.security.sudo.extraRules = [
      {
        users = [ "deploy" ];
        runAs = "root";
        commands = [
          {
            command = "/run/current-system/sw/bin/tailscale up --auth-key\\=file\\:/dev/stdin --timeout\\=60s";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl start tailscaled-set.service";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  });

  flake.modules.nixos.base = {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "none";
      extraSetFlags = [
        "--accept-dns=true"
        "--accept-routes=false"
        "--advertise-routes="
        "--exit-node="
        "--exit-node-allow-lan-access=false"
        "--advertise-exit-node=false"
        "--ssh=false"
        "--webclient=false"
        "--auto-update=false"
      ];
    };
    environment.persistence."/persist".directories = [
      {
        directory = "/var/lib/tailscale";
        user = "root";
        group = "root";
        mode = "0700";
      }
    ];
  };
}
