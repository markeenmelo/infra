{
  fleet.hosts.racknerd = {
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "os-disk"
      "persistence"
      "access"
      "server"
      "vps"
    ];
    deployment.enable = true;
  };
}
