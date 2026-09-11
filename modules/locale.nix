{ lib, ... }:
{
  # Preserve the three installed hosts' explicit timezone, not a new-host default.
  fleet.hosts = lib.genAttrs [ "thinkpad" "racknerd" "bastion" ] (_: {
    module.time.timeZone = "America/Toronto";
  });
}
