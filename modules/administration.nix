{
  flake.modules.nixos.administration = { pkgs, ... }: {
    environment.systemPackages = [
      pkgs.git
      pkgs.jq
      pkgs.just
    ];
    # Repository-pinned deployment and lint tooling comes from nix develop.
  };
}
