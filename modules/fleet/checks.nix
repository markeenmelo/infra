{
  config,
  inputs,
  lib,
  options,
  ...
}:
let
  fixtureFor = config.fleet.validation.fixtureFor;
  # Independent policy oracle: changing host metadata alone must fail validation.
  expectedTracks = config.fleet.validation.expectedTracks;
  tracks = {
    stable = inputs.nixpkgs-stable;
    unstable = inputs.nixpkgs;
  };
  report = config.flake.fleet;
  lock = builtins.fromJSON (builtins.readFile (inputs.self + "/flake.lock"));
  lockedInput = name: lock.nodes.${lock.nodes.root.inputs.${name}};
  # Apply the real host module's type to an empty, evaluation-only definition.
  # This isolates class checking from unrelated deployment option declarations.
  classFixture =
    (options.fleet.hosts.type.getSubOptions [ ]).module.type.merge
      [ ]
      [
        {
          file = "<synthetic-host-module-class-test>";
          value = { };
        }
      ];
  withClass =
    class:
    (lib.evalModules {
      inherit class;
      modules = [ classFixture ];
    }).config;
  checkedReport =
    assert builtins.deepSeq (withClass "nixos") true;
    assert lib.assertMsg (
      !(builtins.tryEval (withClass "homeManager")).success
    ) "The deferred host module must reject composition into a non-NixOS class.";
    assert lib.assertMsg (
      builtins.attrNames config.fleet.validation.hostChecks == [
        "desktop"
        "editors"
        "kernel"
        "nh"
        "printing"
        "secrets"
        "storage"
        "tailscale"
        "workstation"
      ]
    ) "A feature-owned real-host check is missing; review the independent check inventory.";
    assert lib.assertMsg (
      builtins.match "nixos-[0-9]{2}\\.(05|11)" (lockedInput "nixpkgs-stable").original.ref != null
    ) "Stable must lock a numbered NixOS release branch, not an unstable alias.";
    assert lib.assertMsg (
      (lockedInput "nixpkgs").original.ref == "nixpkgs-unstable"
      && !(lock.nodes.root.inputs ? nixpkgs-unstable)
      && (lockedInput "flake-parts").inputs.nixpkgs-lib == [ "nixpkgs" ]
    ) "The default nixpkgs input and flake-parts must use the interactive unstable track.";
    assert lib.assertMsg (
      !(lock.nodes.root.inputs ? home-manager-stable)
      && !(lock.nodes.root.inputs ? home-manager-unstable)
      &&
        (lockedInput "home-manager").original == {
          type = "github";
          owner = "nix-community";
          repo = "home-manager";
        }
      && ((lockedInput "home-manager").flake or true)
      && (lockedInput "home-manager").inputs.nixpkgs == [ "nixpkgs" ]
      &&
        (lockedInput "zen-browser").original == {
          type = "github";
          owner = "youwen5";
          repo = "zen-browser-flake";
        }
      && ((lockedInput "zen-browser").flake or true)
      && (lockedInput "zen-browser").inputs.nixpkgs == [ "nixpkgs" ]
      &&
        (lockedInput "sops-nix").original == {
          type = "github";
          owner = "Mic92";
          repo = "sops-nix";
        }
      && ((lockedInput "sops-nix").flake or true)
      && (lockedInput "sops-nix").inputs.nixpkgs == [ "nixpkgs-stable" ]
    ) "Home Manager, Zen and sops-nix must be default-branch flakes, pinned only in flake.lock.";
    assert lib.assertMsg (
      builtins.attrNames expectedTracks == builtins.attrNames report
    ) "Update the explicit fleet policy oracle when adding/removing a host.";
    lib.mapAttrs (
      name: host:
      let
        system = config.flake.fleetConfigurations.${name};
        cfg = system.config;
        tailscaleEnabled = cfg.fleet.tailscale.enable;
      in
      assert lib.assertMsg (host.track == expectedTracks.${name}) "${name}: wrong Nixpkgs track";
      assert lib.assertMsg (
        host.nixpkgsPath == host.intendedNixpkgsPath
        && host.nixpkgsPath == toString tracks.${expectedTracks.${name}}.outPath
      ) "${name}: actual pkgs source differs from independently required input";
      assert lib.assertMsg (lib.all
        (
          message:
          lib.hasPrefix "BOOTSTRAP:" message
          || lib.hasPrefix "Neither the root account nor any wheel user has a password or SSH authorized key." message
        )
        host.failedAssertions
      ) "${name}: unexpected NixOS assertion: ${lib.concatStringsSep "; " host.failedAssertions}";
      assert lib.assertMsg (
        host.ready -> host.missing == [ ] && host.failedAssertions == [ ]
      ) "${name}: commissioned with unresolved requirements";
      assert lib.assertMsg (
        !cfg.services.xserver.enable
        && !cfg.programs.steam.enable
        && cfg.systemd.enableEmergencyMode
        && cfg.services.openssh.settings.PermitRootLogin == "no"
        && cfg.services.openssh.settings.AllowUsers == [ "marcos" ]
        && cfg.security.sudo.wheelNeedsPassword
        && !cfg.fleet.access.passwordlessSudo
        && cfg.networking.firewall.allowedTCPPorts == [ 22 ]
        &&
          lib.sort builtins.lessThan cfg.networking.firewall.allowedUDPPorts
          == (lib.optional (name == "thinkpad") 5353 ++ lib.optional tailscaleEnabled 41641)
        &&
          cfg.networking.firewall.allowedTCPPortRanges == (
            if name == "thinkpad" then
              [
                {
                  from = 1714;
                  to = 1764;
                }
              ]
            else
              [ ]
          )
        && cfg.networking.firewall.allowedUDPPortRanges == cfg.networking.firewall.allowedTCPPortRanges
      ) "${name}: SSH/firewall/reviewed-Tailscale-rollout/recovery policy regressed";
      assert lib.all (check: check { inherit name host system; }) (
        lib.attrValues config.fleet.validation.hostChecks
      );
      host
      // {
        # Force real per-host packages, /etc/services and initrd even before the
        # final toplevel is permitted. These are evaluations, not real builds.
        components = {
          systemPath = system.config.system.path.drvPath;
          etc = system.config.system.build.etc.drvPath;
          initrd = system.config.system.build.initialRamdisk.drvPath;
          kernel = cfg.boot.kernelPackages.kernel.drvPath;
          kernelVersion = cfg.boot.kernelPackages.kernel.version;
        }
        // lib.optionalAttrs (name == "bastion") {
          zfs = cfg.boot.kernelPackages.${cfg.boot.zfs.package.kernelModuleAttribute}.drvPath;
          zfsVersion = cfg.boot.zfs.package.version;
        }
        // lib.optionalAttrs (name == "thinkpad") {
          home = cfg.home-manager.users.marcos.home.activationPackage.drvPath;
        };
      }
    ) report;

  compositionReport = lib.mapAttrs (
    _: host:
    let
      fixture = fixtureFor host.track "uefi" host.capabilities;
    in
    {
      # Also check the exact shipped subsets: a combined fixture alone can mask
      # a missing dependency by supplying another capability's configuration.
      toplevel = fixture.config.system.build.toplevel.drvPath;
    }
  ) config.fleet.hosts;
in
{
  flake.validation = {
    hosts = checkedReport;
    compositions = compositionReport;
  };
}
