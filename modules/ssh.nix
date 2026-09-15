{
  flake.modules.nixos.server = { config, lib, ... }: {
    options.fleet.sshTailnetOnly = lib.mkEnableOption "separately verified and authorized Tailscale-only OpenSSH cutover";
    config = lib.mkIf config.fleet.sshTailnetOnly {
      assertions = [
        {
          assertion =
            config.services.tailscale.enable
            && config.services.openssh.ports == [ 22 ]
            && !(builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces);
          message = "SSH cutover requires Tailscale, standard OpenSSH port 22 and no blanket interface trust; prove private deploy/admin access and console recovery first.";
        }
      ];
      services.openssh.openFirewall = false;
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
      networking.nftables.tables.ssh-tailnet = {
        family = "inet";
        content = ''
          chain input {
            type filter hook input priority -30; policy accept;
            iifname != { "lo", "tailscale0" } tcp dport 22 drop
          }
        '';
      };
    };
  };
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
