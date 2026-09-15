{
  flake.modules.nixos.desktop = { pkgs, ... }: {
    environment.systemPackages = [
      pkgs.git
      pkgs.jq
    ];
  };
}
