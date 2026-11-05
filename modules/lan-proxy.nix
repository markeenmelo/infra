{ config, ... }:
let
  inherit (config.flake.modules.nixos) caddy;
in
{
  flake.modules.nixos.lan-proxy =
    { config, ... }:
    let
      domain = "marcosmelo.dev";
      # shortcut: bastion's tailnet address is a literal, read it from fleet facts when a second host needs it
      tailnet = "100.105.158.109";
      tailscale = config.services.tailscale.interfaceName;
    in
    {
      imports = [ caddy ];
      services.caddy.virtualHosts."*.${domain}".extraConfig = ''
        tls {
          dns porkbun {
            api_key {env.PORKBUN_API_KEY}
            api_secret_key {env.PORKBUN_SECRET_KEY}
          }
          resolvers 1.1.1.1 9.9.9.9
        }
        handle {
          abort
        }
      '';
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
        allowedTCPPorts = [ 443 ];
        interfaces.${tailscale} = {
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };
      };
    };
}
