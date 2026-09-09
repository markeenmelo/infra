{
  fleet.hosts.dino = {
    system = "x86_64-linux";
    track = "unstable";
    capabilities = [
      "existing-storage"
      "headless"
      "persistence"
      "access"
      "workstation"
      "laptop"
    ];
    deployment = {
      enable = true;
      hostname = "192.168.20.2";
      sshUser = "marcos";
    };
  };
}
