{
  fleet.hosts.beast.module =
    { config, ... }:
    {
      boot.kernelModules = [ "nct6775" ];
      services.hardware.openrgb = {
        enable = true;
        motherboard = "intel";
      };
      fleet.loopbackGuards.openrgb = {
        ports = [ config.services.hardware.openrgb.server.port ];
        users = [ "marcos" ];
      };
      preservation.preserveAt."/persist".directories = [ "/var/lib/OpenRGB" ];
    };
}
