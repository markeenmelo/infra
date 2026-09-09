{
  fleet.hosts.racknerd = {
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
      # Closure trust is deliberately unresolved; do not grant Nix trust to wheel.
    };
  };
}
