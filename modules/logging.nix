{
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
        services.journald =
          if options.services.journald ? settings then
            {
              settings.Journal = lib.mapAttrs (_: lib.mkDefault) journal;
            }
          else
            {
              extraConfig = lib.generators.toKeyValue { } journal;
            };
      };
    };
}
