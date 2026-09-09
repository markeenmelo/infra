{
  fleet.hosts.thinkpad = {
    system = "x86_64-linux";
    track = "unstable";
    capabilities = [
      "os-disk"
      "persistence"
      "access"
      "workstation"
      "laptop"
      "administration"
    ];
    deployment.enable = false;
  };
}
