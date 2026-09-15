{
  fleet.hosts.bastion.module = { lib, pkgs, ... }: {
    system.stateVersion = "26.05";
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "sd_mod"
    ];
    boot.kernelModules = [
      "i2c-i801"
      "i2c-dev"
    ];
    systemd.services.ugreen-leds = {
      description = "Initialize UGREEN front-panel LEDs";
      wantedBy = [ "multi-user.target" ];
      requires = [ "systemd-modules-load.service" ];
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "15s";
        ExecStart = [
          "${lib.getExe pkgs.ugreen-leds-cli} power netdev disk1 disk2 disk3 disk4 -off"
          "${lib.getExe pkgs.ugreen-leds-cli} power -color 0 0 255 -brightness 128 -on"
        ];
      };
    };
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
    boot.loader.limine.extraConfig = "graphics: no";
  };
}
