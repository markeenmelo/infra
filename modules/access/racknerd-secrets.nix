{
  fleet.hosts.racknerd.module.fleet.secrets = {
    ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
    ageRecipient = "age1dpxn0ymj6jyt33yf9ukuekwh93w8r3gsmfx8d3g3g3vhh5dn7ygsdpy48t";
    # The operator attested custody but declined the recovery test; real
    # early decryption remains a prerequisite for commissioning.
    identityReviewed = false;
  };
}
