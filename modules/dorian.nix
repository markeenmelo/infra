{
  flake.modules.nixos.dorian =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      sops.secrets.dorian-token = {
        key = "dorian/token";
        restartUnits = [ "dorian.service" ];
      };

      systemd.services.dorian = {
        description = "Dorian Call of Cthulhu Discord dice roller";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        enableStrictShellChecks = true;
        serviceConfig = {
          DynamicUser = true;
          LoadCredential = "token:${config.sops.secrets.dorian-token.path}";
          Restart = "always";
          RestartSec = 5;
        };
        script = ''
          token=$(< "$CREDENTIALS_DIRECTORY/token")
          export DORIAN_TOKEN="$token"
          exec ${lib.getExe (pkgs.callPackage ./dorian.pkg.nix { })}
        '';
      };
    };
}
