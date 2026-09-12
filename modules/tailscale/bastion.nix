{ config, ... }:
{
  fleet.hosts.bastion.module = {
    fleet.tailscale = {
      # NeedsLogin with an old tag: use the operator-supplied exact-tag key,
      # never force-reset the reviewed, recoverable retained identity.
      enrollmentMode = "auth-key";
      authKeySecret = "tailscale-auth-key";
      stateReviewed = true;
      policyReviewed = true;
    };
    sops.secrets.tailscale-auth-key = {
      sopsFile = ../../secrets/hosts/bastion-tailscale.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
      neededForUsers = false;
      restartUnits = [ "fleet-tailscale.service" ];
    };
  };

  # Native selected-key validation only: never decrypts or installs the secret.
  perSystem.checks.bastion-tailscale-manifest =
    config.flake.fleetConfigurations.bastion.config.system.build.sops-nix-manifest;
}
