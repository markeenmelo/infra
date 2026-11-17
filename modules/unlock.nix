{ config, lib, ... }:
let
  inherit (config.fleet) hosts;
  unlocked = lib.filterAttrs (_: host: host.unlock != null) hosts;
  hostKeyPath = "etc/secrets/initrd/ssh_host_ed25519_key";
in
{
  flake.modules.nixos.unlock =
    { config, lib, ... }:
    let
      inherit (hosts.${config.networking.hostName}) unlock;
    in
    {
      boot.initrd = {
        systemd = {
          network = {
            enable = true;
            inherit (config.systemd.network) networks;
          };
          users.root.shell = "/bin/systemd-tty-ask-password-agent";
        };
        network.ssh = {
          enable = true;
          inherit (unlock) port;
          hostKeys = [ "/persist/${hostKeyPath}" ];
          authorizedKeys = map (
            key: "restrict,pty ${lib.removePrefix "restrict " key}"
          ) config.users.users.deploy.openssh.authorizedKeys.keys;
        };
      };
      fleet.carry = [ hostKeyPath ];
    };

  perSystem =
    { pkgs, ... }:
    {
      apps.unlock = {
        meta.description = "unlock HOST: send the disk passphrase to a host waiting in its initrd, over SSH to its public address as the deploy key, against the pinned initrd host key";
        program = pkgs.writeShellApplication {
          name = "unlock";
          runtimeInputs = [ pkgs.openssh ];
          text = ''
            case ''${1-} in
            ${
              lib.concatStrings (
                lib.mapAttrsToList (
                  name: host:
                  let
                    known = pkgs.writeText "unlock-${name}-known-hosts" ''
                      [${host.publicAddress}]:${toString host.unlock.port} ${host.unlock.hostKey}
                    '';
                  in
                  "  ${name}) exec ssh -t -p ${toString host.unlock.port} -o UserKnownHostsFile=${known} -o GlobalKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes root@${host.publicAddress} ;;\n"
                ) unlocked
              )
            }  *) echo "unlock: no host named ''${1-} takes its passphrase over SSH" >&2; exit 1 ;;
            esac
          '';
        };
      };
    };
}
