{
  fleet.hosts.bastion.module.fleet.secrets = {
    ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
    ageRecipient = "age1p0ecx9y4vn85nccz98427qpfyxfva5kfg9vr6ccqammscuwl0vfsh7rrkf";
    # Dedicated identity provisioned and canary-verified on 2026-09-11.
    # Its own recovery copy/test and early delivery still require verification.
    identityReviewed = false;
  };
}
