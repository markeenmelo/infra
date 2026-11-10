{
  fleet.hosts.thinkpad.module =
    { config, ... }:
    {
      fleet = {
        encryptState = true;
        carry = [ "var/lib/sbctl" ];
      };
      disko.devices.disk.os.device = "/dev/disk/by-id/nvme-eui.00a075013a594e93";
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
