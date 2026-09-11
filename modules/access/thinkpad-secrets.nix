{
  fleet.hosts.thinkpad.module.fleet.secrets = {
    ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
    ageRecipient = "age15r7mf8n0ah32y9xf8jxjvj4yrzsf3y52cucqeyr6hlxtkw63vs0qjz7wgm";
    # 2026-09-10: dedicated-key permissions/recipient/MAC/decryption and
    # existing early runtime binding verified; operator confirms tested
    # independent recovery. New-root boot acceptance remains separate.
    identityReviewed = true;
  };
}
