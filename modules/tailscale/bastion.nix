{
  fleet.hosts.bastion.module.fleet.tailscale = {
    # NeedsLogin with an old tag: use a new exact-tag key, never force-reset
    # the retained identity. Keep rollout disabled until ciphertext is supplied.
    enrollmentMode = "auth-key";
    # Same live/backing file, private modes and non-routing preferences checked;
    # protected host-state recovery and current live policy operator-confirmed.
    stateReviewed = true;
    policyReviewed = true;
  };
}
