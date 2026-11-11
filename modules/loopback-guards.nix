{
  flake.modules.nixos.base =
    { config, lib, ... }:
    let
      guards = config.fleet.loopbackGuards;
    in
    {
      options.fleet.loopbackGuards = lib.mkOption {
        default = { };
        description = "Local ports that answer without authentication, by owner: an nftables output rule rejects connections to them from this host's own processes unless they run as one of `users`.";
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              ports = lib.mkOption {
                type = lib.types.listOf lib.types.port;
                description = "Ports to guard.";
              };
              protocol = lib.mkOption {
                type = lib.types.enum [
                  "tcp"
                  "udp"
                ];
                default = "tcp";
                description = "Transport the ports listen on.";
              };
              users = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "Accounts whose processes may still connect; empty refuses every local process.";
              };
            };
          }
        );
      };
      config = lib.mkIf (guards != { }) {
        networking.nftables.enable = true;
        networking.nftables.tables.loopback-guards = {
          family = "inet";
          content = ''
            chain output {
              type filter hook output priority -150; policy accept;
              ${lib.concatStrings (
                lib.mapAttrsToList (
                  _: guard:
                  ''oifname "lo" ${guard.protocol} dport { ${lib.concatMapStringsSep ", " toString guard.ports} } ''
                  +
                    lib.optionalString (guard.users != [ ])
                      "meta skuid != { ${
                        lib.concatMapStringsSep ", " (user: toString config.users.users.${user}.uid) guard.users
                      } } "
                  + "reject\n"
                ) guards
              )}
            }
          '';
        };
      };
    };
}
