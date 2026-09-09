{ inputs, ... }:
{
  flake.modules.nixos.persistence =
    { config, lib, ... }:
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];
      options.fleet.persistence.rootSize = lib.mkOption {
        type = lib.types.strMatching "([1-9][0-9]*[MG]|[1-9][0-9]?%)";
        default = "25%";
        description = "tmpfs root ceiling, a tunable policy, not reserved RAM. Review memory/build workloads.";
      };
      config = {
        # Actual ephemeral-root semantics, independent of deprecated scripted-initrd hooks.
        fileSystems."/".neededForBoot = true;
        disko.devices.nodev."/" = {
          fsType = "tmpfs";
          mountOptions = [
            "mode=755"
            "size=${config.fleet.persistence.rootSize}"
          ];
        };
        environment.persistence."/persist" = {
          hideMounts = true;
          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd/timers"
          ];
          files = [
            "/etc/machine-id"
            "/var/lib/systemd/random-seed"
          ];
        };
        fleet.bootstrap.missing = lib.optional (
          !(config.fileSystems ? "/persist") || !(config.fileSystems ? "/nix")
        ) "Configure real persistent /persist and /nix filesystems with neededForBoot.";
      };
    };
}
