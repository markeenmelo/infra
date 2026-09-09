{
  flake.modules.nixos.ssh = { config, lib, ... }: {
    # Both server and deployment may import this deferred value. A stable module
    # key deduplicates list definitions (notably persisted keys) in that diamond.
    key = "fleet.ssh";
    config = {
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          PermitEmptyPasswords = false;
          AuthenticationMethods = "publickey";
          X11Forwarding = false;
          AllowAgentForwarding = false;
          AllowTcpForwarding = lib.mkDefault "no";
          MaxAuthTries = 3;
          LoginGraceTime = 30;
          MaxStartups = "10:30:60";
          # All explicitly keyed non-root accounts, including a separately
          # configured deployment account. No root exception during migration.
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
