{
  fleet.hosts.edge.module =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
    };
}
