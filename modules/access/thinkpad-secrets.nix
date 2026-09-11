{
  fleet.hosts.thinkpad.module = {
    fleet = {
      secrets = {
        ageKeyFile = "/persist/var/lib/sops-nix/key.txt";
        # 2026-09-10: dedicated-key permissions/recipient/MAC/decryption and
        # existing early runtime binding verified; operator confirms tested
        # independent recovery. New-root boot acceptance remains separate.
        identityReviewed = true;
      };
      access.passwordSecrets.marcos = "marcos-password-hash";
    };
    sops.secrets.marcos-password-hash = {
      sopsFile = ../../secrets/hosts/thinkpad.yaml;
      neededForUsers = true;
    };
    # Wi-Fi and Tailscale declarations live with their owning concerns.
  };
}
