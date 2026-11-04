{
  fleet.hosts.racknerd.module =
    { modulesPath, ... }:
    {
      imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
    };
}
