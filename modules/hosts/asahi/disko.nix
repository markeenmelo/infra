{
  fleet.hosts.asahi.module = {
    fleet = {
      encryptState = true;
      esp = "/dev/disk/by-partuuid/786d1f59-e9f5-4ecc-9a28-e3966ff1cca3";
    };
    disko.devices.disk.os.device = "/dev/disk/by-partuuid/ce45e724-dd4c-4823-9a36-89cfdf424f5c";
    boot.loader.limine.maxGenerations = 5;
  };
}
