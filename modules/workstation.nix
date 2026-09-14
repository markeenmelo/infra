_: {
  flake.modules.nixos.workstation =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.fleet.workstation = {
        homePersistence = lib.mkOption {
          type = lib.types.enum [
            "bind"
            "filesystem"
          ];
          default = "bind";
          description = "Preserve /home through impermanence, or retain an existing separate early-mounted filesystem without a duplicate bind.";
        };
      };
      config = {
        assertions = [
          {
            assertion =
              config.fleet.workstation.homePersistence == "filesystem"
              -> (
                config.fileSystems ? "/home"
                && config.fileSystems."/home".neededForBoot
                && config.fileSystems."/home".fsType != "tmpfs"
              );
            message = "Separate workstation /home must be durable and neededForBoot.";
          }
        ];
        networking.networkmanager.enable = true;
        environment.systemPackages = [ pkgs.git ];
        environment.persistence."/persist".directories =
          lib.optional (config.fleet.workstation.homePersistence == "bind") "/home"
          ++ [
            {
              directory = "/etc/NetworkManager/system-connections";
              mode = "0700";
            }
            "/var/lib/NetworkManager"
          ];
      };
    };
}
