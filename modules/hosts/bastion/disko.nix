{
  fleet.hosts.bastion.module =
    { config, ... }:
    {
      fleet = {
        encryptState = true;
        carry = [ "var/lib/sbctl" ];
      };
      disko.devices.disk.os.device = "/dev/disk/by-id/nvme-eui.6479a7a2ea200e8e";
      boot.loader.limine.secureBoot.enable = true;
      environment.systemPackages = [ config.boot.loader.limine.secureBoot.sbctl ];
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/sbctl";
          mode = "0700";
        }
      ];
    };
}
