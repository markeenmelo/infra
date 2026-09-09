{
  fleet.hosts.thinkpad = {
    system = "x86_64-linux";
    track = "unstable";
    capabilities = [
      "existing-storage"
      "ssh"
      "hyprland"
      "persistence"
      "access"
      "workstation"
      "laptop"
      "administration"
    ];
    deployment.enable = false;
  };
}
