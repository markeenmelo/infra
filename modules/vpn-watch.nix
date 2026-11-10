{
  flake.modules.nixos.vpn-watch = {
    key = "fleet-vpn-watch";
    imports = [
      (
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          confined =
            namespace:
            lib.attrNames (
              lib.filterAttrs (
                _: unit:
                unit.vpnConfinement.enable
                && unit.vpnConfinement.vpnNamespace == namespace
                && (unit.serviceConfig.Type or "simple") != "oneshot"
              ) config.systemd.services
            );
          perNamespace = f: lib.mkMerge (map f (lib.attrNames config.vpnNamespaces));
        in
        {
          systemd.services = perNamespace (namespace: {
            ${namespace} = {
              upholds = map (name: "${name}.service") (confined namespace);
              startLimitIntervalSec = 3600;
              startLimitBurst = 120;
              serviceConfig = {
                Restart = "on-failure";
                RestartSec = 30;
              };
            };
            "${namespace}-watch" = {
              description = "Restart the ${namespace} tunnel when its handshake is stale";
              unitConfig.ConditionPathExists = "/run/netns/${namespace}";
              path = [
                pkgs.iproute2
                pkgs.wireguard-tools
              ];
              enableStrictShellChecks = true;
              serviceConfig.Type = "oneshot";
              script = ''
                since=$(systemctl show -P ActiveEnterTimestampMonotonic ${namespace}.service)
                (( $(cut -d. -f1 /proc/uptime) - since / 1000000 < 300 )) && exit 0
                latest=$(ip netns exec ${namespace} wg show ${namespace}0 latest-handshakes | cut -f2 | sort -n | tail -n1)
                if (( $(date +%s) - ''${latest:-0} >= 300 )); then
                  echo "last handshake ''${latest:-never}, restarting" >&2
                  systemctl restart ${namespace}.service
                fi
              '';
            };
          });
          systemd.timers = perNamespace (namespace: {
            "${namespace}-watch" = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnActiveSec = "5min";
                OnUnitActiveSec = "2min";
              };
            };
          });
        }
      )
    ];
  };
}
