{
  flake.modules.nixos.base =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      cfg = config.fleet;
    in
    {
      options.fleet = {
        bootstrap = {
          approved = mkOption {
            type = types.bool;
            default = false;
            description = "Set by host readiness metadata, never a substitute for missing facts.";
          };
          missing = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Actionable commissioning blockers contributed by capabilities.";
          };
        };
        installation = {
          stateVersion = mkOption {
            type = types.nullOr (types.strMatching "[0-9]{2}\\.(05|11)");
            default = null;
            description = "Original installation stateVersion, or a deliberate value for a new installation. Never track the input automatically.";
          };
          hardwareReviewed = mkOption {
            type = types.bool;
            default = false;
            description = "Real hardware scan has been reviewed and adapted into a top-level module.";
          };
          networkReviewed = mkOption {
            type = types.bool;
            default = false;
            description = "Actual network/console recovery configuration has been reviewed.";
          };
        };
      };
      config = {
        fleet.bootstrap.missing =
          lib.optional (
            cfg.installation.stateVersion == null
          ) "Set fleet.installation.stateVersion from the installation history."
          ++ lib.optional (
            !cfg.installation.hardwareReviewed
          ) "Supply hardware facts and acknowledge fleet.installation.hardwareReviewed."
          ++ lib.optional (
            !cfg.installation.networkReviewed
          ) "Supply networking and acknowledge fleet.installation.networkReviewed.";
        assertions = [
          {
            assertion = cfg.bootstrap.approved;
            message = "BOOTSTRAP: host is not commissioned (fleet.hosts.<name>.ready = false).";
          }
          {
            assertion = cfg.bootstrap.missing == [ ];
            message = "BOOTSTRAP: ${lib.concatStringsSep " " cfg.bootstrap.missing}";
          }
        ];
        system.stateVersion = lib.mkIf (
          cfg.installation.stateVersion != null
        ) cfg.installation.stateVersion;
        nix.settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          auto-optimise-store = true;
        };
        documentation.nixos.enable = false;
        networking.useDHCP = lib.mkDefault false;
      };
    };
}
