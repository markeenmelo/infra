{
  fleet.hosts.dino = {
    system = "x86_64-linux";
    track = "unstable";
    capabilities = [
      "os-disk"
      "persistence"
      "access"
      "workstation"
      "gaming"
    ];
    deployment.enable = false;
  };
}
