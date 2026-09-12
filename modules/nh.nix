{ lib, ... }:
{
  # ThinkPad-only interactive helper, using the native module and host's pkgs.
  # This is the observed checkout path, not a Nix path copied into the store.
  fleet.hosts.thinkpad.module.programs.nh = {
    enable = true;
    flake = "/home/marcos/projects/infra";
  };

  fleet.validation.hostChecks.nh =
    { name, system, ... }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg (
      cfg.programs.nh.enable == (name == "thinkpad")
      && !cfg.programs.nh.clean.enable
      && !(cfg.systemd.services ? nh-clean)
      && !(cfg.systemd.timers ? nh-clean)
      && cfg.programs.nh.flake == (if name == "thinkpad" then "/home/marcos/projects/infra" else null)
      && (
        if name == "thinkpad" then
          cfg.programs.nh.package.drvPath == system.pkgs.nh.drvPath
          && cfg.environment.variables.NH_FLAKE == "/home/marcos/projects/infra"
        else
          !(cfg.environment.variables ? NH_FLAKE)
      )
    ) "${name}: nh is ThinkPad-only, uses its own pkgs/checkout and must not schedule cleanup";
    true;
}
