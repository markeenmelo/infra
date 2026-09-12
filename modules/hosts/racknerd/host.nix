{
  fleet.hosts.racknerd = {
    # Fresh layout/device, identity/recovery and closure trust remain unreviewed.
    ready = false;
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "racknerd-disko"
      "headless"
      "persistence"
      "access"
      "server"
      "vps"
      "editors"
    ];
    deployment = {
      # Keep deploy-rs disabled until the staged root activation provisions
      # trusted closure transport for marcos.
      enable = false;
      hostname = "72.11.150.242";
      sshUser = "marcos";
      # Operator-chosen 2026-09-10: root-equivalent Nix trust for the solo VPS
      # admin, not blanket wheel trust and not signed closures.
      transport = "trusted-user";
    };
  };
}
