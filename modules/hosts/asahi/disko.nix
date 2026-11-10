{
  fleet.hosts.asahi.module = {
    fleet = {
      encryptState = true;
      esp = "/dev/disk/by-partuuid/cec80b1e-4de3-438f-a9b4-8ee9d80ac570";
    };
    disko.devices.disk.os.device = "/dev/disk/by-partuuid/60874c09-34b8-4a8f-907e-ec5e40e3ac04";
    boot.loader.limine.maxGenerations = 5;
  };
}
