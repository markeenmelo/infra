{
  flake.modules.nixos.base =
    { config, ... }:
    {
      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts =
        config.services.openssh.ports;
      services.openssh = {
        enable = true;
        openFirewall = false;
        authorizedKeysInHomedir = false;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          AllowAgentForwarding = false;
          AllowTcpForwarding = "no";
          AllowStreamLocalForwarding = "no";
          MaxAuthTries = 3;
          LoginGraceTime = 30;
          MaxStartups = "10:30:60";
        };
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };
      fleet.carry = [
        "etc/ssh/ssh_host_ed25519_key"
        "etc/ssh/ssh_host_ed25519_key.pub"
      ];
      preservation.preserveAt."/persist".files = [
        {
          file = "/etc/ssh/ssh_host_ed25519_key";
          how = "symlink";
          configureParent = true;
        }
        {
          file = "/etc/ssh/ssh_host_ed25519_key.pub";
          how = "symlink";
          configureParent = true;
        }
      ];
    };
}
