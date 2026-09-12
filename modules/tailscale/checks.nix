{ config, lib, ... }:
let
  fixtures = config.fleet.validation.fixtures;
  expectedTailscaleRollout = {
    thinkpad = true;
    racknerd = false;
    bastion = false;
  };
  tailscaleFixtures = lib.mapAttrs (
    _: fixture:
    fixture.extendModules {
      modules = [
        ({ lib, ... }: {
          # Synthetic evaluation-only identity, never an exported node/install target.
          networking.hostName = lib.mkForce "thinkpad";
          fleet.tailscale = {
            enable = true;
            tag = "tag:fleet-thinkpad";
            enrollmentMode = "preserve";
            stateReviewed = true;
            policyReviewed = true;
          };
        })
      ];
    }
  ) fixtures;
  tailscaleReport = lib.mapAttrs (
    track: fixture:
    let
      cfg = fixture.config;
      # Assertion failures are data on config.assertions; the NixOS toplevel
      # throws exactly when one is false. Force only the assertion booleans:
      # upstream messages may legitimately throw while their assertion passes,
      # because the toplevel renders failed messages only.
      rejected =
        extra:
        let
          broken = (fixture.extendModules { modules = [ extra ]; }).config;
          forced = builtins.tryEval (lib.all (a: a.assertion) broken.assertions);
        in
        !forced.success || !forced.value;
      enrollment = fixture.extendModules {
        modules = [
          {
            fleet.tailscale.enrollmentMode = lib.mkForce "auth-key";
            fleet.tailscale.authKeySecret = "TEST-ONLY-tailscale";
            # Shape/key-selection fixture, deliberately NOT an actual auth key.
            sops.secrets.TEST-ONLY-tailscale = {
              sopsFile = ../../secrets/hosts/thinkpad.yaml;
              key = "wifi-psk";
              mode = "0400";
              restartUnits = [ "fleet-tailscale.service" ];
            };
          }
        ];
      };
      persisted = lib.filter (
        d: d.dirPath == "/var/lib/tailscale"
      ) cfg.environment.persistence."/persist".directories;
    in
    assert lib.assertMsg (
      cfg.services.tailscale.enable
      && cfg.services.tailscale.authKeyFile == null
      && cfg.services.tailscale.package.drvPath == fixture.pkgs.tailscale.drvPath
      && cfg.services.tailscale.useRoutingFeatures == "none"
      && cfg.services.tailscale.disableTaildrop
      && cfg.services.tailscale.openFirewall
      && lib.elem 41641 cfg.networking.firewall.allowedUDPPorts
      && !(lib.elem "tailscale0" cfg.networking.firewall.trustedInterfaces)
      && builtins.length persisted == 1
      && (builtins.head persisted).mode == "0700"
      &&
        cfg.systemd.services.tailscaled.unitConfig.RequiresMountsFor == [
          "/persist/var/lib/tailscale"
          "/var/lib/tailscale"
        ]
      && !(cfg.systemd.services ? tailscaled-autoconnect)
      && cfg.fleet.bootstrap.missing == [ ]
    ) "${track}: Tailscale package/persistence/enrollment/firewall boundary regressed";
    assert lib.all
      (
        extra:
        lib.assertMsg (rejected extra) "${track}: unsafe Tailscale rollout must fail toplevel evaluation"
      )
      [
        { fleet.tailscale.stateReviewed = lib.mkForce false; }
        { fleet.tailscale.policyReviewed = lib.mkForce false; }
        { fleet.tailscale.enrollmentMode = lib.mkForce null; }
        { fleet.tailscale.enrollmentMode = lib.mkForce "auth-key"; }
        { fleet.tailscale.tag = lib.mkForce "tag:fleet-bastion"; }
        { services.tailscale.extraSetFlags = [ "--ssh" ]; }
        { services.tailscale.authKeyFile = lib.mkForce "/nix/store/TEST-ONLY-UNSAFE-KEY"; }
        { networking.firewall.trustedInterfaces = [ "tailscale0" ]; }
      ];
    assert lib.assertMsg (
      let
        leaked =
          (enrollment.extendModules {
            modules = [
              {
                sops.secrets.TEST-ONLY-tailscale.mode = lib.mkForce "0444";
              }
            ];
          }).config;
        forced = builtins.tryEval (lib.all (a: a.assertion) leaked.assertions);
      in
      !forced.success || !forced.value
    ) "${track}: world-readable Tailscale credential must fail";
    {
      preserveToplevel = cfg.system.build.toplevel.drvPath;
      enrollmentToplevel = enrollment.config.system.build.toplevel.drvPath;
      packageVersion = fixture.pkgs.tailscale.version;
      unsafeRolloutsRejected = true;
      secretPath = enrollment.config.sops.secrets.TEST-ONLY-tailscale.path;
    }
  ) tailscaleFixtures;
in
{
  fleet.validation.hostChecks.tailscale =
    {
      name,
      host,
      system,
    }:
    let
      cfg = system.config;
      tailscaleEnabled = expectedTailscaleRollout.${name};
    in
    assert lib.assertMsg (
      cfg.services.tailscale.enable == tailscaleEnabled
      && cfg.fleet.tailscale.enable == tailscaleEnabled
      && cfg.fleet.tailscale.tag == "tag:fleet-${name}"
      && (
        if tailscaleEnabled then
          let
            key = cfg.sops.secrets.tailscale-auth-key;
          in
          cfg.fleet.tailscale.enrollmentMode == "auth-key"
          && cfg.fleet.tailscale.authKeySecret == "tailscale-auth-key"
          && cfg.fleet.tailscale.stateReviewed
          && cfg.fleet.tailscale.policyReviewed
          && cfg.fleet.tailscale.missing == [ ]
          && cfg.systemd.services ? fleet-tailscale
          && lib.elem "/var/lib/tailscale" host.persistence.directories
          && cfg.services.tailscale.package.drvPath == system.pkgs.tailscale.drvPath
          && cfg.services.tailscale.authKeyFile == null
          && !(lib.elem "tailscale0" cfg.networking.firewall.trustedInterfaces)
          && key.sopsFile == ../../secrets/hosts/thinkpad-tailscale.yaml
          && key.key == "tailscale-auth-key"
          && key.path == "/run/secrets/tailscale-auth-key"
          && key.owner == "root"
          && key.group == "root"
          && key.mode == "0400"
          && !key.neededForUsers
          && key.restartUnits == [ "fleet-tailscale.service" ]
        else
          cfg.fleet.tailscale.enrollmentMode == null
          && cfg.fleet.tailscale.authKeySecret == null
          && !cfg.fleet.tailscale.stateReviewed
          && !cfg.fleet.tailscale.policyReviewed
          && cfg.fleet.tailscale.missing != [ ]
          && !(cfg.systemd.services ? fleet-tailscale)
          && !(lib.elem "/var/lib/tailscale" host.persistence.directories)
      )
    ) "${name}: reviewed Tailscale rollout regressed";
    true;
  flake.validation.tailscale = tailscaleReport;
  perSystem.checks = lib.mapAttrs' (
    track: fixture:
    lib.nameValuePair "${track}-tailscale-cli" (
      fixture.pkgs.runCommand "${track}-tailscale-cli" { nativeBuildInputs = [ fixture.pkgs.tailscale ]; }
        ''
          tailscale up --help > up-help 2>&1
          tailscale set --help > set-help 2>&1
          grep -q 'file:' up-help
          for flag in accept-dns accept-routes ssh shields-up advertise-routes advertise-exit-node advertise-connector exit-node exit-node-allow-lan-access operator netfilter-mode hostname; do
            grep -q -- "--$flag" up-help
            grep -q -- "--$flag" set-help
          done
          grep -q -- '--auto-update' set-help
          grep -q -- '--webclient' set-help
          grep -q -- '--advertise-tags' up-help
          touch "$out"
        ''
    )
  ) tailscaleFixtures;
}
