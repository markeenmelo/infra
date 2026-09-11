{ lib, ... }:
{
  # User-selected account policy. This public key was read from each installed
  # host's authorized_keys and selected for reuse; no private material is copied.
  fleet.hosts = lib.genAttrs [ "thinkpad" "racknerd" "bastion" ] (_: {
    module = {
      fleet.access = {
        admin = "marcos";
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYdnogT40vOG0eZn4guvWq33q6VANCYXEYsxOSIsVbc"
        ];
        # Missing host ciphertext/identity remains a blocker. ThinkPad's verified
        # encrypted source is supplied separately; never reuse it on other hosts.
        passwordSecrets.marcos = lib.mkDefault null;
        passwordlessSudo = false;
      };
      users.users.marcos.uid = 1000;
    };
  });
}
