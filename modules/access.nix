{
  flake.modules.nixos.base = {
    users = {
      mutableUsers = false;
      users.root.hashedPassword = "!";
      users.marcos = {
        isNormalUser = true;
        description = "Marcos Melo";
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYdnogT40vOG0eZn4guvWq33q6VANCYXEYsxOSIsVbc"
        ];
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
