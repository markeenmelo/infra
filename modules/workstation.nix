{ lib, ... }:
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
        homePersistence = lib.mkOption {
          type = lib.types.enum [
            "bind"
            "filesystem"
          ];
          default = "bind";
          description = "Preserve /home through impermanence, or retain an existing separate early-mounted filesystem without a duplicate bind.";
        };
        usersReviewed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Interactive accounts, passwords and privileges have been explicitly configured.";
        };
      };
      config = {
        # A workstation can be deliberately headless; desktop/gaming software
        # is not a prerequisite for this baseline's commissioning.
        fleet.bootstrap.missing =
          lib.optional (!config.fleet.workstation.usersReviewed)
            "Configure interactive users and migrate credentials; acknowledge fleet.workstation.usersReviewed.";
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
        # Deliberate user-data boundary: games, saves, documents and credentials survive.
        # No claim that /home is minimal per-application persistence or encrypted.
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

  # Synthetic evaluation-only review, never a host commissioning fact.
  fleet.validation.fixtureModules.workstation = _: { fleet.workstation.usersReviewed = true; };
  fleet.validation.hostChecks.workstation =
    {
      name,
      host,
      system,
    }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg (
      (name == "thinkpad")
      -> (
        cfg.fileSystems."/home".neededForBoot
        && !(lib.elem "/home" host.persistence.directories)
        && cfg.services.power-profiles-daemon.enable
      )
    ) "${name}: preserve laptop home mounts and power management";
    true;
}
