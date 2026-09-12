{ config, lib, ... }:
{
  flake.modules.nixos.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      services = {
        # Discovery for the approved IPP/eSCL devices. Upstream defaults keep
        # discovery local-only, unpublished and off the firewall.
        avahi = {
          enable = true;
          nssmdns4 = true;
        };
        printing = {
          enable = true;
          # cups-browsed is the only deliberate deviation from the local-only
          # upstream defaults.
          browsed.enable = false;
        };
      };
      hardware.sane = {
        enable = true;
        extraBackends = [ pkgs.sane-airscan ];
      };
      users.users = lib.optionalAttrs (config.fleet.access.admin != null) {
        ${config.fleet.access.admin}.extraGroups = [
          "scanner"
          "lp"
        ];
      };
      # Native CUPS owns queues/PPDs here; caches and job spool remain ephemeral.
      environment.persistence."/persist".directories = [ "/var/lib/cups" ];
    };
  flake.modules.homeManager.desktop = { pkgs, ... }: { home.packages = [ pkgs.simple-scan ]; };
  # Endpoint recovered from the current printer configuration, not a discovered
  # scanner URI or a certificate-verification claim. Verify after authorization.
  fleet.hosts.thinkpad.module = { lib, ... }: {
    hardware.printers = {
      ensureDefaultPrinter = "Epson_ET-3850";
      ensurePrinters = [
        {
          name = "Epson_ET-3850";
          description = "Epson EcoTank ET-3850";
          deviceUri = "ipps://192.168.4.20:631/ipp/print";
          model = "everywhere";
          ppdOptions."printer-is-shared" = "false";
        }
      ];
    };
    systemd.services.ensure-printers = {
      # `-m everywhere` queries the printer even when its queue already exists.
      # Keep native provisioning explicit; ordinary boots use persisted CUPS
      # queues/PPDs without needing the home network. Never retry it on rebuild.
      wantedBy = lib.mkForce [ ];
      restartIfChanged = false;
    };
  };

  fleet.validation.hostChecks.printing =
    {
      name,
      host,
      system,
    }:
    let
      cfg = system.config;
    in
    assert lib.assertMsg
      (
        name != "thinkpad"
        || (
          cfg.systemd.services.ensure-printers.wantedBy == [ ]
          && cfg.systemd.services.ensure-printers.requiredBy == [ ]
          && cfg.systemd.services.ensure-printers.startAt == [ ]
          && !cfg.systemd.services.ensure-printers.restartIfChanged
          && !(cfg.systemd.timers ? ensure-printers)
          && !(cfg.systemd.services ? ensure-printer-classes)
          && lib.all (unit: !(lib.elem "ensure-printers.service" (unit.wants ++ unit.requires))) (
            lib.attrValues cfg.systemd.services ++ lib.attrValues cfg.systemd.targets
          )
          && !cfg.services.printing.stateless
          && lib.elem "/var/lib/cups" host.persistence.directories
          && cfg.hardware.printers.ensureDefaultPrinter == "Epson_ET-3850"
        )
      )
      "${name}: printer provisioning must be manual, with persistent queues/PPDs and no boot/rebuild network dependency";
    true;

  perSystem.checks = {
    thinkpad-printer-provisioning =
      let
        thinkpad = config.flake.fleetConfigurations.thinkpad;
        cfg = thinkpad.config;
      in
      thinkpad.pkgs.runCommand "thinkpad-printer-provisioning" { } ''
        ${lib.getExe thinkpad.pkgs.python3} ${./assets/test-printer-provisioning.py} \
          ${lib.trim cfg.systemd.services.ensure-printers.serviceConfig.ExecStart} \
          ${thinkpad.pkgs.cups}/bin/lpadmin \
          ${cfg.systemd.units."ensure-printers.service".unit}/ensure-printers.service
        touch "$out"
      '';
  };
}
