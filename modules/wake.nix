{ config, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      oracle-boot = pkgs.writeShellApplication {
        name = "oracle-boot";
        runtimeInputs = [
          pkgs.netcat
          pkgs.oci-cli
        ];
        text = ''
          export OCI_CLI_USER=''${TF_VAR_user_ocid:?} OCI_CLI_TENANCY=''${TF_VAR_tenancy_ocid:?} OCI_CLI_FINGERPRINT=''${TF_VAR_fingerprint:?}
          export OCI_CLI_KEY_CONTENT=''${TF_VAR_private_key:?} OCI_CLI_REGION=''${TF_VAR_region:?}
          name=$1 address=$2
          instance() {
            oci compute instance list --compartment-id "$OCI_CLI_TENANCY" --display-name "$name" \
              --lifecycle-state "$1" --query 'data[0].id' --raw-output
          }
          action=START
          id=$(instance STOPPED)
          if [ -z "$id" ]; then
            if nc -z -w 5 "$address" 443 2> /dev/null; then
              echo "wake: $name answers on $address, so it is up" >&2
              exit 1
            fi
            action=RESET
            id=$(instance RUNNING)
          fi
          [ -n "$id" ] || { echo "wake: Oracle has no stopped or running instance named $name" >&2; exit 1; }
          oci compute instance action --instance-id "$id" --action "$action" > /dev/null
        '';
      };
    in
    {
      apps.wake = {
        meta.description = "wake HOST: power on bastion by Wake-on-LAN from a machine at home (it works from the Home VLAN, not over the tailnet), or edge through the Oracle Cloud API";
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
              edge) sops exec-env secrets/oracle/operator.yaml "${lib.getExe oracle-boot} edge ${config.fleet.hosts.edge.publicAddress}" ;;
              *) echo "wake: name bastion or edge, not ''${1-}" >&2; exit 1 ;;
            esac
          '';
        };
      };
    };
}
