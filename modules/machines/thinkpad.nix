{
  fleet.hosts.thinkpad = {
    system = "x86_64-linux";
    track = "unstable";
    capabilities = [
      "existing-storage"
      "ssh"
      "desktop"
      "persistence"
      "access"
      "workstation"
      "laptop"
      "administration"
    ];
    deployment.enable = false;
    # 2026-09-10: commissioning reviews recorded (docs/hosts.md). Local
    # activation target pending first-boot acceptance; not a deployment flag.
    ready = true;
  };
}
