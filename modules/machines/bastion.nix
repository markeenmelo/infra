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
    };
  };
}
