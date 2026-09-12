{ config, inputs, ... }:
let
  desktopHome = config.flake.modules.homeManager.desktop;
in
{
  # One deliberately selected desktop bundle. Its files own concerns across
  # classes; a new filename does not need another named capability/import list.
  flake.modules.nixos.desktop =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      # modulesPath is supplied before module collection by the selected NixOS
      # evaluator. Guard the actual track here, including indirect imports, rather
      # than teaching fleet.nix or the fixture constructor about desktop names.
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
          backupFileExtension = null;
        };
      };
    };

  fleet.hosts.thinkpad.module = {
    # Pre-activation review, 2026-09-10: greeter/UWSM, password-first PAM,
    # locking, portals, audio and mobile display. Runtime acceptance remains
    # separately recorded in docs/hosts.md; this refactor changes no approval.
    fleet.desktop.reviewed = true;
    # Deliberate initial compatibility baseline for this home, not its input version.
    home-manager.users.marcos.home.stateVersion = "26.05";
  };
}
