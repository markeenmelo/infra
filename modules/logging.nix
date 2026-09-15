let
  journald =
    persistent:
    { lib, options, ... }:
    let
      journal =
        if persistent then
          {
            Storage = "persistent";
            SystemMaxUse = "256M";
          }
        else
          { Storage = "volatile"; };
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
