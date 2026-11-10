let
  # shortcut: repeats the printer's fixed lease in opentofu/unifi, pass it as a fact if a second consumer appears
  printer = "192.168.4.20";
in
{
  flake.modules.nixos.desktop =
    { pkgs, ... }:
    {
      services.printing = {
        enable = true;
        drivers = [ pkgs.epson-escpr2 ];
      };
      hardware.printers = {
        ensureDefaultPrinter = "ET-3850";
        ensurePrinters = [
          {
            name = "ET-3850";
            description = "EPSON ET-3850 Series";
            location = "Home";
            deviceUri = "ipps://${printer}/ipp/print";
            model = "epson-inkjet-printer-escpr2/Epson-ET-3850_Series-epson-escpr2-en.ppd";
            ppdOptions.PageSize = "Letter";
          }
        ];
      };
      hardware.sane = {
        enable = true;
        extraBackends = [
          pkgs.sane-airscan
          (pkgs.writeTextFile {
            name = "airscan-et-3850";
            destination = "/etc/sane.d/airscan.conf";
            text = ''
              [devices]
              "EPSON ET-3850" = https://${printer}/eSCL, escl
            '';
          })
        ];
      };
      users.users.marcos.extraGroups = [
        "lp"
        "scanner"
      ];
    };

  flake.modules.homeManager.desktop =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.simple-scan ];
    };
}
