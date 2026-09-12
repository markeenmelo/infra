{
  fleet.hosts.bastion = {
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "existing-storage"
      "headless"
      "persistence"
      "access"
      "server"
      "nas"
    ];
    deployment = {
      enable = true;
      hostname = "192.168.2.2";
      sshUser = "marcos";
      # Explicitly authorized and verified against the live daemon, 2026-09-11.
      transport = "trusted-user";
    };
  };
}
