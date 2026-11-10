{ config, lib, ... }:
let
  lan = lib.mapAttrs (_: host: host.lan) (
    lib.filterAttrs (_: host: host.lan != null) config.fleet.hosts
  );
  inherit (lib.head (lib.attrValues lan)) gateway;
  hosts = builtins.toJSON (lib.mapAttrs (_: host: host.tailnetAddress) config.fleet.hosts);
  settings = ../opentofu/unifi/settings.json;
  program = ../opentofu/unifi/settings.jq;
in
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
            export TF_VAR_fleet_hosts=${lib.escapeShellArg hosts}
            export TF_VAR_fleet_lan=${lib.escapeShellArg (builtins.toJSON lan)}
            export TF_CLI_ARGS_init="-input=false -lockfile=readonly -backend-config=path=$state/terraform.tfstate"
            command=$(printf '%q ' tofu -chdir="opentofu/$project" "$@")
            if [ -e "secrets/$project/api.yaml" ]; then
              command="sops exec-env $(printf '%q %q' "secrets/$project/api.yaml" "$command")"
            fi
            exec sops exec-env "secrets/$project/operator.yaml" "$command"
          '';
        };
      };
      apps.unifi-settings = {
        meta.description = "unifi-settings check|apply: compare the gateway settings no provider writes with opentofu/unifi/settings.json, or merge them in";
        program = pkgs.writeShellApplication {
          name = "unifi-settings";
          runtimeInputs = [
            pkgs.curl
            pkgs.git
            pkgs.jq
            pkgs.sops
          ];
          text = ''
            case ''${1-} in
              check | apply) ;;
              *)
                echo "usage: unifi-settings check|apply" >&2
                exit 2
                ;;
            esac
            if [ -z "''${UNIFI_API_KEY-}" ]; then
              cd "$(git rev-parse --show-toplevel)"
              exec sops exec-env secrets/unifi/operator.yaml "$(printf '%q ' "$0" "$@")"
            fi
            # shortcut: unverified TLS like the provider's allow_insecure, verify once the gateway serves a certificate for the domain
            api() {
              curl -fsSk --max-time 30 -H @<(printf 'X-API-KEY: %s\n' "$UNIFI_API_KEY") \
                -H 'Content-Type: application/json' "$@"
            }
            drift() {
              api https://${gateway}/proxy/network/api/s/default/get/setting |
                jq --slurpfile want ${settings} -f ${program}
            }
            changes=$(drift)
            jq -r '.[] | "setting \(.key):", "  \(.changes[])"' <<< "$changes"
            if jq -e 'length == 0' <<< "$changes" > /dev/null; then
              exit 0
            fi
            if [ "$1" = check ]; then
              exit 1
            fi
            jq -c '.[]' <<< "$changes" | while read -r change; do
              jq .body <<< "$change" |
                api -X PUT --data-binary @- "https://${gateway}/proxy/network/api/s/default/set/setting/$(jq -r .key <<< "$change")" |
                jq -e '(.meta.rc // "ok") == "ok"' > /dev/null
            done
            if ! drift | jq -e 'length == 0' > /dev/null; then
              echo "still drifting after apply" >&2
              exit 1
            fi
          '';
        };
      };
      checks.opentofu = pkgs.runCommand "opentofu" { } ''
        ${lib.getExe pkgs.opentofu} fmt -check -diff -recursive ${../opentofu}
        touch $out
      '';
      checks.unifi-settings = pkgs.runCommand "unifi-settings" { nativeBuildInputs = [ pkgs.jq ]; } ''
        jq -n '{meta: {rc: "ok"}, data: [{key: "usg", upnp_enabled: true, kept: 1}, {key: "doh", state: "manual"}]}' > have.json
        jq -n '{usg: {upnp_enabled: false}, doh: {state: "manual"}, usg_geo: {ip_filtering: {enabled: true}}}' > want.json
        jq --slurpfile want want.json -f ${program} have.json | jq -e '
          map(.key) == ["usg", "usg_geo"]
          and .[0].changes == ["upnp_enabled: true -> false"]
          and .[0].body == {key: "usg", upnp_enabled: false, kept: 1}
          and .[1].body == {key: "usg_geo", ip_filtering: {enabled: true}}'
        jq --slurpfile want ${settings} -f ${program} have.json > /dev/null
        touch $out
      '';
    };
}
