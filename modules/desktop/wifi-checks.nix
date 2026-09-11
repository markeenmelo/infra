{ config, lib, ... }:
let
  # Evaluation-only campus profile/manifest branch, never an exported host.
  # Key selection alone can pass on encrypted markers; actual credential/MAC
  # verification is a separate private operation, not performed by checks.
  senecaTemplate =
    (config.flake.fleetConfigurations.thinkpad.extendModules {
      modules = [
        { fleet.wifi.senecaSopsFile = lib.mkForce ../../secrets/hosts/thinkpad-senecanet.yaml; }
      ];
    }).config;
  wifiReport =
    let
      thinkpad = config.flake.fleetConfigurations.thinkpad;
      cfg = thinkpad.config;
      campus = senecaTemplate.networking.networkmanager.ensureProfiles.profiles.SenecaNET;
      absent =
        (thinkpad.extendModules {
          modules = [
            {
              fleet.wifi.senecaSopsFile = lib.mkForce null;
            }
          ];
        }).config;
      home = cfg.networking.networkmanager.ensureProfiles.profiles.MN-Home;
    in
    assert lib.assertMsg
      (
        home.wifi-security.psk == "$HOME_WIFI_PSK"
        && home.wifi-security.psk-flags == 0
        && cfg.sops.secrets.wifi-psk.mode == "0400"
        && cfg.sops.secrets.wifi-psk.owner == "root"
        && cfg.networking.networkmanager.ensureProfiles.secrets.entries == [ ]
        &&
          cfg.networking.networkmanager.ensureProfiles.environmentFiles
          == [ "/run/fleet-wifi-environment/credentials.env" ]
        && lib.elem "fleet-wifi-environment.service" cfg.systemd.services.NetworkManager-ensure-profiles.requires
        && campus.wifi-security.key-mgmt == "wpa-eap"
        && campus."802-1x".eap == "peap"
        && campus."802-1x".phase2-auth == "mschapv2"
        && campus."802-1x".ca-cert == "/etc/ssl/certs/ca-certificates.crt"
        && campus."802-1x".domain-suffix-match == "senecapolytechnic.ca"
        && campus."802-1x".anonymous-identity == ""
        && campus."802-1x".identity == "$SENECA_IDENTITY"
        && campus."802-1x".password == "$SENECA_PASSWORD"
        && campus."802-1x".password-flags == 0
        && !campus.connection.autoconnect
        &&
          lib.all
            (
              name:
              let
                secret = senecaTemplate.sops.secrets.${name};
              in
              secret.mode == "0400"
              && secret.owner == "root"
              && secret.group == "root"
              && secret.sopsFile == ../../secrets/hosts/thinkpad-senecanet.yaml
            )
            [
              "seneca-identity"
              "seneca-password"
            ]
        && !(absent.networking.networkmanager.ensureProfiles.profiles ? SenecaNET)
        && lib.any (lib.hasInfix "SenecaNET is not provisioned while null") absent.fleet.bootstrap.missing
      )
      "Wi-Fi must retain root-only runtime secrets, PEAP certificate/name validation and missing-campus-credential blocking.";
    {
      runtimeSecrets = true;
      campusCertificateValidation = true;
      missingCampusCredentialsBlocked = true;
    };
in
{
  flake.validation.wifi = wifiReport;
  perSystem = { pkgs, ... }: {
    checks = {
      wifi-secret-environment = pkgs.runCommand "wifi-secret-environment" { } ''
        ${lib.getExe pkgs.python3} ${./assets/test-wifi-environment.py} \
          ${./assets/wifi-environment.py} ${lib.getLib pkgs.glib}/lib/libglib-2.0.so ${lib.getExe pkgs.envsubst}
        touch "$out"
      '';
      # Ciphertext shape/key selection only, never credential/decryption acceptance.
      thinkpad-wifi-manifest =
        config.flake.fleetConfigurations.thinkpad.config.system.build.sops-nix-manifest;
      senecanet-template-manifest = senecaTemplate.system.build.sops-nix-manifest;
    };
  };
}
