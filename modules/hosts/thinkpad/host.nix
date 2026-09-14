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
    module.home-manager.users.marcos.home.stateVersion = "26.05";
    deployment.enable = false;
  };
}
