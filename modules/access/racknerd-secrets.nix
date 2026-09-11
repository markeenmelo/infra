{
  fleet.hosts.racknerd.module = {
    fleet = {
      secrets = {
        ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
        # The operator attested custody but declined the recovery test; real
        # early decryption remains a prerequisite for commissioning.
        identityReviewed = false;
      };
      access.passwordSecrets.marcos = "marcos-password-hash";
    };
    sops.secrets.marcos-password-hash = {
      sopsFile = ../../secrets/hosts/racknerd.yaml;
      neededForUsers = true;
    };
  };
}
