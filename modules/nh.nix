{
  # ThinkPad-only interactive helper, using the native module and host's pkgs.
  # This is the observed checkout path, not a Nix path copied into the store.
  fleet.hosts.thinkpad.module.programs.nh = {
    enable = true;
    flake = "/home/marcos/projects/infra";
    # Preserve recovery generations; never schedule pruning as a convenience.
    clean.enable = false;
  };
}
