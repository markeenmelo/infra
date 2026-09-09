{
  flake.modules.nixos.workstation =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.fleet.workstation = {
        desktopReviewed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "An actual desktop/session and graphics configuration has been chosen and tested.";
        };
        usersReviewed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Interactive accounts, passwords and privileges have been explicitly configured.";
        };
      };
      config = {
        fleet.bootstrap.missing =
          lib.optional (!config.fleet.workstation.desktopReviewed)
            "Choose and configure a desktop/session and graphics; acknowledge fleet.workstation.desktopReviewed."
          ++ lib.optional (
            !config.fleet.workstation.usersReviewed
          ) "Configure interactive users; acknowledge fleet.workstation.usersReviewed.";
        networking.networkmanager.enable = true;
        environment.systemPackages = [ pkgs.git ];
        # Deliberate user-data boundary: games, saves, documents and credentials survive.
        # No claim that /home is minimal per-application persistence or encrypted.
        environment.persistence."/persist".directories = [
          "/home"
          {
            directory = "/etc/NetworkManager/system-connections";
            mode = "0700";
          }
          "/var/lib/NetworkManager"
        ];
      };
    };
}
