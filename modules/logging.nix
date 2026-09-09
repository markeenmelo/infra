{
  # A logging concern contributes to the existing persistence capability instead
  # of requiring another entry in every host's composition.
  flake.modules.nixos.persistence =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      persistent = config.fleet.logging.persistent;
      journal = {
        Storage = if persistent then "persistent" else "volatile";
        SystemMaxUse = "256M";
      };
    in
    {
      options.fleet.logging.persistent = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Retain bounded journal history; defaults to volatile on interactive machines.";
      };
      config = {
        environment.persistence."/persist".directories = lib.optional persistent "/var/log/journal";
        # Verified API difference, localized and based on options, NOT channel names.
        # Remove the fallback once both locked tracks expose settings.Journal.
        services.journald =
          if options.services.journald ? settings then
            {
              settings.Journal = lib.mapAttrs (_: lib.mkDefault) journal;
            }
          else
            {
              # Normal-priority lines merge with unrelated tuning; mkDefault would
              # discard the whole storage policy when another feature adds a line.
              extraConfig = lib.generators.toKeyValue { } journal;
            };
      };
    };
}
