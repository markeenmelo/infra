{
  flake.modules.nixos.fwupd = {
    services.fwupd.enable = true;
    preservation.preserveAt."/persist".directories = [ "/var/lib/fwupd" ];
  };
}
