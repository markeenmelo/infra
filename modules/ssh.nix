{
  flake.modules.nixos.base = { config, lib, ... }: {
    config = {
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AuthenticationMethods = "publickey";
          AllowAgentForwarding = false;
          AllowTcpForwarding = lib.mkDefault "no";
          MaxAuthTries = 3;
          LoginGraceTime = 30;
          MaxStartups = "10:30:60";
          AllowUsers = builtins.attrNames (
            lib.filterAttrs (
              name: user: name != "root" && user.openssh.authorizedKeys.keys != [ ]
            ) config.users.users
          );
        };
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };
      environment.persistence."/persist".files = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };
  };
}
