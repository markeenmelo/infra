{
  flake.modules.nixos.vps = {
    config = {
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
    };
  };
}
