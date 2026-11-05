{
  flake.modules.darwin.base.services.tailscale.enable = true;

  flake.modules.nixos.base =
    { config, ... }:
    {
      sops.secrets.tailscale-auth-key = {
        sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
        restartUnits = [ "tailscaled-autoconnect.service" ];
      };
      services = {
        tailscale = {
          enable = true;
          openFirewall = true;
          authKeyFile = config.sops.secrets.tailscale-auth-key.path;
          disableTaildrop = true;
        };
        resolved.enable = true;
      };
      fleet.carry = [ "var/lib/tailscale" ];
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/tailscale";
          mode = "0700";
        }
      ];
    };
}
