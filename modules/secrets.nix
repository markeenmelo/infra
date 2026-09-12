{ inputs, ... }:
{
  flake.modules.nixos.secrets =
    { config, lib, ... }:
    let
      cfg = config.fleet.secrets;
    in
    {
      key = "fleet-secrets";
      imports = [ inputs.sops-nix.nixosModules.sops ];
      options.fleet.secrets = {
        ageKeyFile = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.strMatching "/persist/var/lib/sops-nix/[a-zA-Z0-9_-][a-zA-Z0-9._-]*"
          );
          default = null;
          description = "Verified dedicated age identity location on early-mounted persistence, never a Nix path/private key value.";
        };
        ageRecipient = lib.mkOption {
          type = lib.types.nullOr (lib.types.strMatching "age1[a-z0-9]+");
          default = null;
          description = "Verified public recipient of this host's dedicated age identity. Null remains unresolved; never infer it from a key-file path.";
        };
        identityReviewed = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Identity custody, matching recipients, root-only permissions, recovery and early decryption have actually been verified.";
        };
      };
      config = {
        sops = {
          validateSopsFiles = true;
          age = {
            keyFile = cfg.ageKeyFile;
            generateKey = false;
            sshKeyPaths = [ ];
          };
          gnupg.sshKeyPaths = [ ];
        };
        # Direct /persist contents survive already; no late bind, key generation
        # or permission-changing migration is performed by this capability.
        fleet.bootstrap.missing =
          lib.optional (
            cfg.ageKeyFile == null
          ) "Supply fleet.secrets.ageKeyFile from verified identity provisioning."
          ++
            lib.optional (!cfg.identityReviewed)
              "Verify SOPS identity custody, recipients, early decryption and recovery; acknowledge fleet.secrets.identityReviewed.";
        assertions = [
          {
            assertion =
              config.sops.age.keyFile == cfg.ageKeyFile
              && !config.sops.age.generateKey
              && config.sops.age.sshKeyPaths == [ ]
              && config.sops.gnupg.sshKeyPaths == [ ]
              && config.sops.gnupg.home == null;
            message = "Fleet SOPS must use only its explicit persistent age identity, without generation or implicit SSH/GPG imports.";
          }
          {
            assertion = config.sops.validateSopsFiles && !config.sops.useTmpfs;
            message = "Fleet SOPS requires ciphertext validation and ramfs secret storage.";
          }
          {
            assertion = config.fileSystems."/persist".neededForBoot or false;
            message = "SOPS identity storage must be mounted early at /persist, not through a late impermanence bind.";
          }
          {
            assertion =
              !config.services.userborn.enable
              && !config.systemd.sysusers.enable
              && !config.sops.useSystemdActivation;
            message = "Fleet SOPS currently requires the reviewed activation-script account backend; research ordering before migrating it.";
          }
        ];
      };
    };

  perSystem = { pkgs, ... }: {
    checks.secret-files =
      pkgs.runCommand "secret-files"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.jq
            pkgs.yq-go
          ];
        }
        ''
          cd ${inputs.self}
          bash modules/secrets/check-secrets.sh
          bash modules/secrets/test-secret-check.sh
          touch "$out"
        '';
  };
}
