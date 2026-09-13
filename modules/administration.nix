{
  flake.modules.nixos.administration = { pkgs, ... }: {
    environment.systemPackages = [
      pkgs.git
      pkgs.jq
      pkgs.just
    ];
  };
}
