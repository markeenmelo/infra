{
  fleet.hosts.bastion.module =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      systemd = lib.getExe' config.systemd.package;
    in
    {
      services.apcupsd = {
        enable = true;
        hooks = {
          onbattery = "${systemd "systemd-run"} --unit=ups-power-saver --collect ${lib.getExe' config.services.power-profiles-daemon.package "powerprofilesctl"} launch -p power-saver ${lib.getExe' pkgs.coreutils "sleep"} infinity";
          offbattery = "${systemd "systemctl"} stop ups-power-saver";
        };
        configText = ''
          UPSNAME bastion
          UPSCABLE usb
          UPSTYPE usb
          DEVICE
          NISIP 127.0.0.1
          BATTERYLEVEL 50
          MINUTES 5
        '';
      };
      services.prometheus.exporters.apcupsd = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 19162;
        apcupsdAddress = "127.0.0.1:3551";
      };
      fleet.scrapeTargets.apcupsd = config.services.prometheus.exporters.apcupsd.port;
      systemd.services = {
        apcupsd.serviceConfig.Restart = "on-failure";
        apcupsd-killpower.after = [ "umount.target" ];
      };
    };
}
