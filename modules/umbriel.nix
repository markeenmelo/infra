{
  flake.modules.nixos.desktop = {
    programs.umbriel.enable = true;
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
