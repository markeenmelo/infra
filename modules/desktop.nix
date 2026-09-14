{ config, inputs, ... }:
let
  desktopHome = config.flake.modules.homeManager.desktop;
in
{
  flake.modules.nixos.desktop =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports =
        assert lib.assertMsg (
          toString modulesPath == "${inputs.nixpkgs}/nixos/modules"
        ) "The desktop/Home Manager capability is supported only on the unstable track.";
        [ inputs.home-manager.nixosModules.home-manager ];
      config = {
        assertions = [
          {
            assertion = !(config.services.greetd.settings ? initial_session);
            message = "The fleet desktop requires authenticated login, never greetd autologin.";
          }
          {
            assertion = config.home-manager.useGlobalPkgs && config.home-manager.useUserPackages;
            message = "The desktop must use its host's packages and NixOS-managed user profiles.";
          }
        ];
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          sharedModules = [ desktopHome ];
        };
      };
    };

}
