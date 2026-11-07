{ config, ... }:
let
  inherit (config.flake.modules.nixos) caddy;
  inherit (config.fleet) domain;
in
{
  flake.modules.nixos.lan-proxy =
    { config, lib, ... }:
    let
      # shortcut: bastion's tailnet address is a literal, read it from fleet facts when a second host needs it
      tailnet = "100.105.158.109";
      tailscale = config.services.tailscale.interfaceName;
    in
    {
      imports = [ caddy ];
      services.caddy.virtualHosts."*.${domain}".extraConfig = lib.mkMerge [
        (lib.mkBefore ''
          tls {
            dns porkbun {
              api_key {env.PORKBUN_API_KEY}
              api_secret_key {env.PORKBUN_SECRET_KEY}
            }
            resolvers 1.1.1.1 9.9.9.9
          }
          import identity
        '')
        (lib.concatStrings (
          lib.mapAttrsToList (name: app: ''
            @${name} host ${name}.${domain}
            handle @${name} {
              ${lib.optionalString app.tailnetOnly ''
                @${name}-outside not remote_ip 100.64.0.0/10
                abort @${name}-outside
              ''}
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
