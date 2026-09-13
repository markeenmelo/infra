{
  fleet.hosts.thinkpad = {
    system = "x86_64-linux";
    track = "unstable";
    capabilities = [
      "thinkpad-disko"
      "ssh"
      "desktop"
      "persistence"
      "access"
      "workstation"
      "laptop"
      "administration"
      "editors"
    ];
    deployment.enable = false;
    ready = false;
  };
}
