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
    # The unchanged encrypted file also carries wifi-psk. It is deliberately not
    # declared/decrypted here: NetworkManager secret-agent migration is separate.
  };
}
