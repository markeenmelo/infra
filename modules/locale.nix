{ lib, ... }:
{
  fleet.hosts = lib.genAttrs [ "thinkpad" "racknerd" "bastion" ] (_: {
    module.time.timeZone = "America/Toronto";
  });
}
