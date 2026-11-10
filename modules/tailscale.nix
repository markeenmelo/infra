{
  flake.modules.darwin.desktop.homebrew.casks = [ "tailscale-app" ];

  flake.modules.nixos.base =
    { config, ... }:
    {
      sops.secrets.tailscale-auth-key.restartUnits = [ "tailscaled-autoconnect.service" ];
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
