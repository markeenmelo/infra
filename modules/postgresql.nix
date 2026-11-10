{
  flake.modules.nixos.postgresql = {
    key = "fleet-postgresql";
    imports = [
      (
        { config, pkgs, ... }:
        {
          services.postgresql = {
            enable = true;
            package = pkgs.postgresql_17;
            dataDir = "/srv/postgresql/${config.services.postgresql.package.psqlSchema}";
          };
          systemd.services.postgresql.unitConfig = {
            AssertPathExists = "${config.services.postgresql.dataDir}/PG_VERSION";
            RequiresMountsFor = config.services.postgresql.dataDir;
          };
        }
      )
    ];
  };
}
