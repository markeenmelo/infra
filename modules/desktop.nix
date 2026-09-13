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
      options.fleet.desktop.reviewed = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Graphical login, fingerprint/password fallback, locking/sleep, portals, audio and mobile displays have been reviewed. Not an eGPU/HDR certification.";
      };
      config = {
        fleet.bootstrap.missing =
          lib.optional (!config.fleet.desktop.reviewed)
            "Verify desktop login, fingerprint/password fallback, locking/sleep, portals, audio and mobile display; acknowledge fleet.desktop.reviewed.";
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

  fleet.hosts.thinkpad.module = {
    fleet.desktop.reviewed = true;
    home-manager.users.marcos.home.stateVersion = "26.05";
  };
}
