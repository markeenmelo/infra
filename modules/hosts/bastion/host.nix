{
  fleet.hosts.bastion = {
    system = "x86_64-linux";
    track = "stable";
    ready = true;
    capabilities = [
      "bastion-disko"
      "headless"
      "persistence"
      "access"
      "server"
      "nas"
    ];
    module = {
      fleet.installation.networkReviewed = true;
      fleet.secrets = {
        ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
        ageRecipient = "age1su25ytldd4uye705w6jllwzkmpdkprruq5mzpcrth0e9zcmcyewspeck6q";
        identityReviewed = true;
      };
    };
  };
}
