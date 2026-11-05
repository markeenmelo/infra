{
  perSystem =
    { lib, pkgs, ... }:
    {
      apps.tofu = {
        meta.description = "tofu PROJECT ARGS: run OpenTofu in opentofu/PROJECT with the operator credentials and the project's host-shared api.yaml when it has one, state under XDG_STATE_HOME";
        program = pkgs.writeShellApplication {
          name = "tofu";
          runtimeInputs = [
            pkgs.git
            pkgs.opentofu
            pkgs.sops
          ];
          text = ''
            project=$1
            shift
            cd "$(git rev-parse --show-toplevel)"
            state="''${XDG_STATE_HOME:-$HOME/.local/state}/infra/$project"
            mkdir -p "$state"
            export TF_CLI_ARGS_init="-input=false -lockfile=readonly -backend-config=path=$state/terraform.tfstate"
            command=$(printf '%q ' tofu -chdir="opentofu/$project" "$@")
            if [ -e "secrets/$project/api.yaml" ]; then
              command="sops exec-env $(printf '%q %q' "secrets/$project/api.yaml" "$command")"
            fi
            exec sops exec-env "secrets/$project/operator.yaml" "$command"
          '';
        };
      };
      checks.opentofu = pkgs.runCommand "opentofu" { } ''
        ${lib.getExe pkgs.opentofu} fmt -check -diff -recursive ${../opentofu}
        touch $out
      '';
    };
}
