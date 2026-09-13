_: {
  flake.modules.nixos.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services = {
        avahi = {
          enable = true;
          nssmdns4 = true;
        };
        printing = {
          enable = true;
          browsed.enable = false;
        };
      };
      hardware.sane = {
        enable = true;
        extraBackends = [ pkgs.sane-airscan ];
      };
      users.users = lib.optionalAttrs (config.fleet.access.admin != null) {
        ${config.fleet.access.admin}.extraGroups = [
          "scanner"
          "lp"
        ];
      };
      environment.persistence."/persist".directories = [ "/var/lib/cups" ];
    };
  flake.modules.homeManager.desktop = { pkgs, ... }: { home.packages = [ pkgs.simple-scan ]; };
  fleet.hosts.thinkpad.module = { lib, ... }: {
    hardware.printers = {
      ensureDefaultPrinter = "Epson_ET-3850";
      ensurePrinters = [
        {
          name = "Epson_ET-3850";
          description = "Epson EcoTank ET-3850";
          deviceUri = "ipps://192.168.4.20:631/ipp/print";
          model = "everywhere";
          ppdOptions."printer-is-shared" = "false";
        }
      ];
    };
    systemd.services.ensure-printers = {
      wantedBy = lib.mkForce [ ];
      restartIfChanged = false;
    };
  };
}
