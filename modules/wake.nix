{ config, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      oracle-boot = pkgs.writeShellApplication {
        name = "oracle-boot";
        runtimeInputs = [ pkgs.oci-cli ];
        text = ''
          export OCI_CLI_USER=''${TF_VAR_user_ocid:?} OCI_CLI_TENANCY=''${TF_VAR_tenancy_ocid:?} OCI_CLI_FINGERPRINT=''${TF_VAR_fingerprint:?}
          export OCI_CLI_KEY_CONTENT=''${TF_VAR_private_key:?} OCI_CLI_REGION=''${TF_VAR_region:?}
          instance=$(oci compute instance list --compartment-id "$OCI_CLI_TENANCY" --display-name "$1" \
            --lifecycle-state STOPPED --query 'data[0].id' --raw-output)
          [ -n "$instance" ] || { echo "wake: Oracle has no stopped instance named $1" >&2; exit 1; }
          oci compute instance action --instance-id "$instance" --action START > /dev/null
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
              edge) sops exec-env secrets/oracle/operator.yaml "${lib.getExe oracle-boot} edge" ;;
              *) echo "wake: name bastion or edge, not ''${1-}" >&2; exit 1 ;;
            esac
          '';
        };
      };
    };
}
