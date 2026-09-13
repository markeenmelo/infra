{
  fleet.hosts.racknerd = {
    ready = true;
    system = "x86_64-linux";
    track = "stable";
    capabilities = [
      "racknerd-disko"
      "headless"
      "persistence"
      "access"
      "server"
      "vps"
    ];
  };
}
