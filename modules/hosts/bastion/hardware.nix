{
  fleet.hosts.bastion.module =
    { config, pkgs, ... }:
    {
      hardware = {
        firmware = [ pkgs.linux-firmware ];
        cpu.intel.updateMicrocode = true;
      };
      boot = {
        extraModulePackages = [ config.boot.kernelPackages.it87 ];
        kernelModules = [
          "it87"
          "it87_wdt"
        ];
        kernelParams = [
          "ahci.mask_port_ext=0xf"
          "ahci.mobile_lpm_policy=3"
        ];
        blacklistedKernelModules = [
          "iTCO_wdt"
          "intel_oc_wdt"
        ];
      };
      systemd = {
        settings.Manager.RuntimeWatchdogSec = "30s";
        services.nix-daemon.serviceConfig.AllowedCPUs = "2-5";
      };
    };
}
