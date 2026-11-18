{ config, ... }:
let
  inherit (config.flake.modules.nixos) caddy;
  inherit (config.fleet) domain hosts;
in
{
  flake.modules.nixos.lan-proxy =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      tailnet = hosts.${config.networking.hostName}.tailnetAddress;
      tailscale = config.services.tailscale.interfaceName;
    in
    {
      imports = [ caddy ];
      sops.secrets = lib.genAttrs [ "PORKBUN_API_KEY" "PORKBUN_SECRET_KEY" ] (_: {
        sopsFile = ../secrets/porkbun/api.yaml;
      });
      services.caddy.virtualHosts."*.${domain}" = {
        logFormat = null;
        extraConfig = lib.mkMerge [
          (lib.mkBefore ''
            import porkbun
            import identity
          '')
          (lib.concatStrings (
            lib.mapAttrsToList (name: app: ''
              @${name} host ${name}.${domain}
              handle @${name} {
                reverse_proxy ${app.address}:${toString app.port}
              }
            '') config.fleet.web.apps
          ))
          (lib.mkAfter ''
            handle {
              abort
            }
          '')
        ];
      };
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = false;
        settings = {
          interface = tailscale;
          bind-dynamic = true;
          no-resolv = true;
          no-hosts = true;
          address = "/${domain}/${tailnet}";
        };
      };
      systemd.services.certificate-watch = {
        description = "Count certificates logged for the domain that the proxy does not hold";
        startAt = "daily";
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "caddy.service"
        ];
        unitConfig.RequiresMountsFor = [ config.fleet.metricsDir ];
        enableStrictShellChecks = true;
        path = [
          pkgs.coreutils
          pkgs.curl
          pkgs.jq
          pkgs.openssl
        ];
        serviceConfig = {
          Type = "oneshot";
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ config.fleet.metricsDir ];
        };
        script = ''
          file=${config.fleet.metricsDir}/certificate-watch.prom
          [ -e "$file" ] || printf 'certificate_watch_last_success_timestamp_seconds %s\n' "$(date +%s)" > "$file"
          held=$(openssl s_client -connect 127.0.0.1:443 -servername auth.${domain} < /dev/null 2> /dev/null \
            | openssl x509 -noout -pubkey | openssl pkey -pubin -outform DER | openssl dgst -sha256 -r | cut -d ' ' -f 1) || exit 0
          [ -n "$held" ] || exit 0
          since=$(date --utc --date '7 days ago' +%Y-%m-%dT%H:%M:%SZ)
          unexpected=0
          after=
          while :; do
            page=$(curl --fail --silent --show-error --max-time 60 --retry 3 \
              "https://api.certspotter.com/v1/issuances?domain=${domain}&include_subdomains=true&after=$after") || exit 0
            last=$(jq --raw-output '.[-1].id // empty' <<< "$page") || exit 0
            [ -n "$last" ] || break
            count=$(jq --arg held "$held" --arg since "$since" \
              '[.[] | select(.not_before >= $since and .pubkey_sha256 != $held)] | length' <<< "$page") || exit 0
            unexpected=$((unexpected + count))
            after=$last
          done
          printf 'certificate_watch_unexpected %s\ncertificate_watch_last_success_timestamp_seconds %s\n' "$unexpected" "$(date +%s)" \
            > "$file.tmp"
          mv "$file.tmp" "$file"
        '';
      };
      networking.firewall = {
        allowedTCPPorts = [
          80
          443
        ];
        allowedUDPPorts = [ 443 ];
        interfaces.${tailscale} = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };
      };
    };
}
