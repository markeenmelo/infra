{
  fleet.hosts.thinkpad.module = {
    fleet.tailscale = {
      enrollmentMode = "auth-key";
      authKeySecret = "tailscale-auth-key";
      # Operator-reviewed retained profile/permissions and recoverable backup;
      # deleted control-plane node needs the newly supplied exact-tag key.
      stateReviewed = true;
      policyReviewed = true;
    };
    sops.secrets.tailscale-auth-key = {
      sopsFile = ../../secrets/hosts/thinkpad-tailscale.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
      neededForUsers = false;
      restartUnits = [ "fleet-tailscale.service" ];
    };
  };
}
