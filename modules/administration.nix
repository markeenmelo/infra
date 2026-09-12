{
  flake.modules.nixos.administration = { pkgs, ... }: {
    environment.systemPackages = [
      pkgs.git
      pkgs.jq
      pkgs.just
    ];
    # Repository tooling now comes from native devenv; just remains a general
    # administration tool for unrelated projects, not this repo's task runner.
  };
}
