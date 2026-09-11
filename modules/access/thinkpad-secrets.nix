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
      tailscale = {
        enrollmentMode = "auth-key";
        authKeySecret = "tailscale-auth-key";
        # Operator-reviewed retained profile/permissions and recoverable backup;
        # deleted control-plane node needs the newly supplied exact-tag key.
        stateReviewed = true;
        policyReviewed = true;
      };
    };
    sops.secrets.marcos-password-hash = {
      sopsFile = ../../secrets/hosts/thinkpad.yaml;
      neededForUsers = true;
    };
    sops.secrets.tailscale-auth-key = {
      sopsFile = ../../secrets/hosts/thinkpad-tailscale.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
      neededForUsers = false;
      restartUnits = [ "fleet-tailscale.service" ];
    };
    # The unchanged wifi-psk ciphertext is consumed by desktop/wifi.nix. The
    # separately audited campus ciphertext is selected in desktop/thinkpad.nix.
  };
}
