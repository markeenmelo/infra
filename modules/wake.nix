{ config, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      racknerd-boot = pkgs.writeShellApplication {
        name = "racknerd-boot";
        runtimeInputs = [ pkgs.curl ];
        text = ''
          response=$(printf 'key=%s&hash=%s&action=boot' "$RACKNERD_API_KEY" "$RACKNERD_API_HASH" |
            curl -fsS --data @- https://ctrl.racknerd.com/api/client/command.php)
          [[ $response == *"<status>success</status>"* ]] || { echo "wake: RackNerd answered: $response" >&2; exit 1; }
        '';
      };
    in
    {
      apps.wake = {
        meta.description = "wake HOST: power on bastion by Wake-on-LAN from its LAN, or racknerd through the RackNerd SolusVM client API";
        program = pkgs.writeShellApplication {
          name = "wake";
          runtimeInputs = [
            pkgs.git
            pkgs.sops
            pkgs.wakeonlan
          ];
          text = ''
            cd "$(git rev-parse --show-toplevel)"
            case ''${1-} in
              bastion) wakeonlan ${config.fleet.hosts.bastion.lan.mac} ;;
              racknerd) sops exec-env secrets/racknerd/operator.yaml ${lib.getExe racknerd-boot} ;;
              *) echo "wake: name bastion or racknerd, not ''${1-}" >&2; exit 1 ;;
            esac
          '';
        };
      };
    };
}
