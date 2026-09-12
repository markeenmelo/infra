{
  flake.modules.nixos.desktop = {
    hardware.bluetooth.enable = true;
    environment.persistence."/persist".directories = [
      {
        directory = "/var/lib/bluetooth";
        mode = "0700";
      }
    ];
  };
}
