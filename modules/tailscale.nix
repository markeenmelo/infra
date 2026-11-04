{
  flake.modules.nixos.base =
    { config, ... }:
    {
      sops.secrets.tailscale-auth-key.sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
      services = {
        tailscale = {
          enable = true;
          openFirewall = true;
          authKeyFile = config.sops.secrets.tailscale-auth-key.path;
          disableTaildrop = true;
        };
        resolved.enable = true;
      };
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/tailscale";
          mode = "0700";
        }
      ];
    };
}
