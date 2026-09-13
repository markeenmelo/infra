{
  fleet.hosts.thinkpad.module = {
    fleet.tailscale = {
      enrollmentMode = "auth-key";
      authKeySecret = "tailscale-auth-key";
      stateReviewed = true;
      policyReviewed = true;
    };
    sops.secrets.tailscale-auth-key = {
      sopsFile = ../../secrets/hosts/thinkpad-tailscale.yaml;
      owner = "root";
    };
  };
}
