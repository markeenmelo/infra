let
  keyFile = "/persist/var/lib/luks/games.key";
in
{
  fleet.hosts.beast.module =
    { config, ... }:
    {
      fleet.carry = [
        "var/lib/luks"
        "var/lib/sbctl"
      ];
      disko.devices.disk.os.device = "/dev/disk/by-id/nvme-eui.0025385c81b12835";
      environment.systemPackages = [ config.boot.loader.limine.secureBoot.sbctl ];
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/sbctl";
          mode = "0700";
        }
      ];
      environment.etc.crypttab.text = ''
        games /dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b416db901 ${keyFile} nofail,discard
      '';
      fileSystems."/games" = {
        device = "/dev/mapper/games";
        fsType = "ext4";
        options = [
          "nofail"
          "nosuid"
          "nodev"
          "noatime"
        ];
      };
      systemd.tmpfiles.rules = [
        "d /persist/var/lib/luks 0700 root root -"
        "z ${keyFile} 0400 root root -"
      ];
    };
}
