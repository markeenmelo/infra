{ config, ... }:
let
  inherit (config.flake.modules.nixos) caddy;
  inherit (config.fleet) domain hosts;
in
{
  flake.modules.nixos.lan-proxy =
    { config, lib, ... }:
    let
      tailnet = hosts.${config.networking.hostName}.tailnetAddress;
      tailscale = config.services.tailscale.interfaceName;
    in
    {
      imports = [ caddy ];
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
