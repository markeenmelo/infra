let
  journald =
    persistent:
    { lib, options, ... }:
    let
      journal = {
        Storage = if persistent then "persistent" else "volatile";
        SystemMaxUse = "256M";
      };
    in
    {
      environment.persistence."/persist".directories = lib.optional persistent "/var/log/journal";
      services.journald =
        if options.services.journald ? settings then
          { settings.Journal = journal; }
        else
          { extraConfig = lib.generators.toKeyValue { } journal; };
    };
in
{
  flake.modules.nixos = {
    server = journald true;
    desktop = journald false;
  };
}
