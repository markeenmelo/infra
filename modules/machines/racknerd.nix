{
  fleet.hosts.racknerd = {
    # 2026-09-10 commissioning approval after the six attested reviews below.
    ready = true;
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "existing-storage"
      "headless"
      "persistence"
      "access"
      "server"
      "vps"
    ];
    deployment = {
      enable = true;
      hostname = "72.11.150.242";
      sshUser = "marcos";
      # Operator-chosen 2026-09-10: root-equivalent Nix trust for the solo VPS
      # admin, not blanket wheel trust and not signed closures.
      transport = "trusted-user";
    };
  };
}
