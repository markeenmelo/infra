{
  fleet.hosts.beast.module =
    { config, lib, ... }:
    {
      hardware = {
        cpu.intel.updateMicrocode = true;
        nvidia = {
          open = true;
          powerManagement.enable = true;
        };
      };
      services.xserver.videoDrivers = [ "nvidia" ];
      nixpkgs.config.allowUnfreePackages = [
        "nvidia-x11"
        "nvidia-settings"
      ];
      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "nvme"
          "usbhid"
          "usb_storage"
          "sd_mod"
        ];
        kernelModules = [ "kvm-intel" ];
      };
      networking.networkmanager.connectionConfig."ethernet.wake-on-lan" = 64;
      systemd.services.wifi-off = {
        description = "Start with the Wi-Fi radio off; beast is wired";
        wantedBy = [ "multi-user.target" ];
        after = [ "NetworkManager.service" ];
        requires = [ "NetworkManager.service" ];
        serviceConfig.Type = "oneshot";
        script = "${lib.getExe' config.networking.networkmanager.package "nmcli"} radio wifi off";
      };
    };
}
