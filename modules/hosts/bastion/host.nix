{
  fleet.hosts.bastion = {
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "bastion-disko"
      "persistence"
      "access"
      "server"
    ];
  };
}
