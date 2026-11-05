{
  fleet.hosts.bastion.module = {
    boot.kernelParams = [ "consoleblank=60" ];
    services.power-profiles-daemon.enable = true;
    powerManagement.powertop = {
      enable = true;
      preStart = ''
        for p in /sys/class/scsi_host/*/link_power_management_policy; do
          if [ -e "$p" ]; then printf '%s %s\n' "$p" "$(cat "$p")"; fi
        done > /run/powertop-lpm
      '';
      postStart = ''
        while read -r p v; do
          [ "$(cat "$p")" = "$v" ] || echo "$v" > "$p"
        done < /run/powertop-lpm
        for i in /sys/bus/usb/drivers/usbhid/*:* /sys/bus/usb/drivers/usb-storage/*:* /sys/bus/usb/drivers/uas/*:*; do
          [ -e "$i" ] || continue
          echo on > "$i/../power/control"
        done
      '';
    };
    systemd.services.powertop.enableStrictShellChecks = true;
  };
}
