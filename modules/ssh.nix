{
  flake.modules.nixos.ssh = {
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
