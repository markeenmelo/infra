{ lib, ... }:
{
  # User-selected account policy. This public key was read from each installed
  # host's authorized_keys and selected for reuse; no private material is copied.
  fleet.hosts = lib.genAttrs [ "thinkpad" "racknerd" "bastion" "dino" ] (_: {
    module = {
      fleet.access = {
        admin = "marcos";
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYdnogT40vOG0eZn4guvWq33q6VANCYXEYsxOSIsVbc"
        ];
        # Desired runtime delivery contract, NOT an observed/provisioned file.
        # Existing sops-managed passwords must be migrated securely, outside Git.
        passwordFile = "/persist/secrets/marcos-password-hash";
        passwordlessSudo = false;
      };
      users.users.marcos.uid = 1000;
    };
  });
}
