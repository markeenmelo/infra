{
  fleet.hosts.thinkpad.module = {
    # Observed read-only (2026-09-09) plus privileged scans (2026-09-10):
    # ThinkPad T14 Gen 3 (21AH00BNUS), Intel i7-1270P, i915 8086:46a6.
    # Scan review evidence: docs/hosts.md#current-status.
    fleet.installation = {
      stateVersion = "26.05";
      hardwareReviewed = true;
      # Pre-activation review 2026-09-10: system-owned MN-Home and strict
      # PEAP/MSCHAPv2 SenecaNET from root-only SOPS secrets via the ordered
      # environment/ensure-profiles units; legacy helper/agent absent.
      # Evidence and first-boot acceptance: docs/hosts.md#current-status.
      networkReviewed = true;
    };
    boot = {
      initrd = {
        availableKernelModules = [
          "xhci_pci"
          "thunderbolt"
          "nvme"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
        kernelModules = [ "dm-snapshot" ];
      };
      kernelModules = [ "kvm-intel" ];
    };
    hardware.enableRedistributableFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;
    # Scanner subvolume diagnostics are a reviewed bind-mount fallback; retain
    # USB/SCSI support from the earlier scan (no initrd/boot test). Stock 7.x
    # kernel via modules/kernel.nix; native i915 for Alder Lake-P — no
    # experimental xe/force_probe or unverified eGPU driver.
  };
}
