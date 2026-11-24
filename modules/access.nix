{
  flake.modules.nixos.base =
    { config, ... }:
    {
      sops.secrets.marcos-password-hash = {
        sopsFile = ../secrets/shared/login.yaml;
        neededForUsers = true;
      };
      users = {
        mutableUsers = false;
        users.root.hashedPassword = "!";
        users.marcos = {
          isNormalUser = true;
          description = "Marcos Melo";
          extraGroups = [ "wheel" ];
          hashedPasswordFile = config.sops.secrets.marcos-password-hash.path;
          openssh.authorizedKeys.keys = [ (import ./_operator-key.nix) ];
        };
      };
      services.openssh.settings.AllowUsers = [ "marcos" ];
      preservation.preserveAt."/persist".directories = [
        {
          directory = "/home/marcos";
          user = "marcos";
          group = "users";
          mode = "0700";
        }
      ];
    };
}
