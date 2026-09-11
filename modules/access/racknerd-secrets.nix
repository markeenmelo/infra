{
  fleet.hosts.racknerd.module = {
    fleet = {
      secrets = {
        ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
        # 2026-09-10 operator attestation of custody/recovery; real early
        # decryption is accepted at first activation, as on ThinkPad.
        identityReviewed = true;
      };
      access.passwordSecrets.marcos = "marcos-password-hash";
    };
    sops.secrets.marcos-password-hash = {
      sopsFile = ../../secrets/hosts/racknerd.yaml;
      neededForUsers = true;
    };
  };
}
