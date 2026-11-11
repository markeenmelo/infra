{
  flake.modules.darwin.base = {
    system.primaryUser = "marcos";
    users.users.marcos = {
      home = "/Users/marcos";
      description = "Marcos Melo";
    };
    security.pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };
  };

  flake.modules.nixos.base = {
    users = {
      mutableUsers = false;
      users.root.hashedPassword = "!";
    };
  };

  flake.modules.nixos.server.users.allowNoPasswordLogin = true;

  flake.modules.nixos.desktop =
    { config, ... }:
    {
      sops.secrets.marcos-password-hash = {
        sopsFile = ../secrets/shared/login.yaml;
        neededForUsers = true;
      };
      users.users.marcos = {
        isNormalUser = true;
        description = "Marcos Melo";
        extraGroups = [ "wheel" ];
        hashedPasswordFile = config.sops.secrets.marcos-password-hash.path;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYdnogT40vOG0eZn4guvWq33q6VANCYXEYsxOSIsVbc"
        ];
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
