{
  fleet.hosts.bastion = {
    system = "x86_64-linux";
    track = "stable";
    ready = true;
    capabilities = [
      "bastion-disko"
      "headless"
      "persistence"
      "access"
      "server"
      "nas"
    ];
    module = {
      fleet.installation.networkReviewed = true;
    };
  };
}
