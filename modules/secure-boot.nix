{
  flake.modules.nixos.secure-boot =
    { config, ... }:
    {
      fleet.carry = [ "var/lib/sbctl" ];
      boot.loader.limine.secureBoot.enable = true;
      environment.systemPackages = [ config.boot.loader.limine.secureBoot.sbctl ];
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/var/lib/sbctl";
          mode = "0700";
        }
      ];
    };
}
