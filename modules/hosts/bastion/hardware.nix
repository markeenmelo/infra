{
  fleet.hosts.bastion.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      fleet.renderDevice = "/dev/dri/igpu";
      hardware = {
        firmware = [ pkgs.linux-firmware ];
        cpu.intel.updateMicrocode = true;
        graphics = {
          enable = true;
          extraPackages = [
            pkgs.intel-compute-runtime
            pkgs.intel-media-driver
            pkgs.vpl-gpu-rt
          ];
        };
      };
      services.udev.extraRules = ''
        SUBSYSTEM=="drm", KERNEL=="renderD*", DRIVERS=="i915|xe", TAG+="systemd", SYMLINK+="${lib.removePrefix "/dev/" config.fleet.renderDevice}"
      '';
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
