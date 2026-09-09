{
  fleet.hosts.bastion = {
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "os-disk"
      "persistence"
      "access"
      "server"
      "nas"
    ];
    deployment.enable = true;
  };
}
