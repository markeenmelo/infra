{ config, inputs, ... }:
{
  flake.modules.nixos.nixflix = {
    key = "fleet-nixflix";
    imports = [
      inputs.nixflix.nixosModules.default
      config.flake.modules.nixos.vpn-watch
      (
        { config, ... }:
        let
          inherit (config.nixflix) stateDir;
          media = dirOf config.nixflix.mediaDir;
        in
        {
          nixflix = {
            enable = true;
            stateDir = "/srv/nixflix-state";
            mediaDir = "/srv/media/media";
            downloadsDir = "/srv/media/downloads";
          };
          systemd.services.nixflix-setup-dirs.unitConfig.RequiresMountsFor = [
            stateDir
            media
          ];
        }
      )
    ];
  };
}
