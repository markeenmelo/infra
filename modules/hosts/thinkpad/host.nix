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
    # Fresh reinstall candidate selected 2026-09-12. The running encrypted
    # installation's acceptance does not approve this new plain layout.
    ready = false;
  };
}
