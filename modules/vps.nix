{
  flake.modules.nixos.vps = { config, lib, ... }: {
    options.fleet.vps.providerReviewed = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Provider boot, networking, virtualization and rescue-console facts have been verified.";
    };
    config = {
      fleet.bootstrap.missing = lib.optional (
        !config.fleet.vps.providerReviewed
      ) "Supply provider-specific facts separately; acknowledge fleet.vps.providerReviewed.";
      services.fail2ban = {
        enable = true;
        maxretry = 5;
        bantime = "1h";
        jails.sshd.settings.findtime = "10m";
      };
      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/fail2ban";
          mode = "0750";
        }
      ];
      systemd.services.fail2ban.unitConfig.RequiresMountsFor = [ "/var/lib/fail2ban" ];
      # No HTTP(S) port is opened until a real reverse proxy is commissioned.
    };
  };
  # Synthetic evaluation-only provider review, never an observed machine fact.
  fleet.validation.fixtureModules.vps = _: { fleet.vps.providerReviewed = true; };
}
