{
  fleet.hosts.thinkpad = {
    system = "x86_64-linux";
    track = "unstable";
    capabilities = [
      "existing-storage"
      "headless"
      "persistence"
      "access"
      "workstation"
      "laptop"
      "administration"
    ];
    deployment.enable = false;
  };
}
