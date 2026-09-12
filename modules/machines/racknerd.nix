{
  fleet.hosts.racknerd = {
    # Remains blocked until the dedicated identity passes early decryption and
    # recovery review, then the staged root activation provisions Nix trust.
    ready = false;
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "existing-storage"
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
