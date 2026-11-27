{
  flake.modules.nixos.github-token =
    { config, ... }:
    {
      sops.secrets.nix-access-tokens = {
        sopsFile = ../secrets/shared/github.yaml;
        owner = "marcos";
        group = config.users.users.marcos.group;
      };
      home-manager.users.marcos = {
        nix.extraOptions = "!include ${config.sops.secrets.nix-access-tokens.path}";
        home.sessionVariables.TACK_NIX_CONF_TOKENS = "1";
      };
    };
}
