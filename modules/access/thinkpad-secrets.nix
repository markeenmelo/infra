{
  fleet.hosts.thinkpad.module = {
    fleet = {
      secrets.ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
      # identityReviewed remains false pending fresh custody/boot/recovery review.
      access.passwordSecrets.marcos = "marcos-password-hash";
    };
    sops.secrets.marcos-password-hash = {
      sopsFile = ../../secrets/hosts/thinkpad.yaml;
      neededForUsers = true;
    };
    # The unchanged wifi-psk ciphertext is consumed by desktop/wifi.nix. Campus
    # identity/password remain a separate, explicitly blocked provisioning step.
  };
}
