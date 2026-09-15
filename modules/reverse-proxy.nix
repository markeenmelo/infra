let
  web = {
    domain = "marcosmelo.dev";
    authHostname = "auth.marcosmelo.dev";
    authAddress = "100.96.133.3";
    certificateEmail = "marcosmelo@proton.me";
  };
in
{
  fleet.hosts.racknerd.module.fleet.web = web // {
    exposure = "public";
  };
  fleet.hosts.bastion.module.fleet.web = web // {
    exposure = "lan";
    lanIPv4 = "192.168.2.2";
    lanInterface = "enp3s0";
    lanIPv4Ranges = [
      "192.168.2.0/24"
      "192.168.10.0/24"
    ];
    lanIPv6 = null;
    lanIPv6Ranges = [ ];
  };

  flake.modules.nixos.server =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkOption types;
      cfg = config.fleet.web;
      nullable =
        type: description:
        mkOption {
          type = types.nullOr type;
          default = null;
          inherit description;
        };
      hostname = types.strMatching "[a-z0-9]([a-z0-9.-]*[a-z0-9])?";
      ipv4 = types.strMatching "([0-9]{1,3}\\.){3}[0-9]{1,3}";
      ipv6 = types.strMatching "[0-9a-fA-F:]+:[0-9a-fA-F:]+";
      secretPath =
        name:
        if
          name != null
          && builtins.hasAttr name config.sops.secrets
          && config.sops.secrets.${name}.owner == "root"
          && config.sops.secrets.${name}.mode == "0400"
        then
          config.sops.secrets.${name}.path
        else
          "";
      secretNames = builtins.attrValues cfg.secrets;
      authURL = "http://${
        lib.optionalString (cfg.authAddress != null && lib.hasInfix ":" cfg.authAddress) "["
      }${toString cfg.authAddress}${
        lib.optionalString (cfg.authAddress != null && lib.hasInfix ":" cfg.authAddress) "]"
      }:9091";
      pluginName = "github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin";
      plugin = pkgs.fetchFromGitHub {
        owner = "maxlerebourg";
        repo = "crowdsec-bouncer-traefik-plugin";
        rev = "bef5dfaadbb07381af02ec4e7391e49214ebf953";
        hash = "sha256-hefOKDVsBxn+rCAylPHqbCNfPMbU/vtO4QpiftIPcUU=";
      };
      plugins = pkgs.linkFarm "traefik-local-plugins" [
        {
          name = "src/${pluginName}";
          path = plugin;
        }
      ];
      entrypoint = address: {
        inherit address;
        forwardedHeaders = {
          insecure = false;
          trustedIPs = [ ];
        };
        http.tls.certResolver = "porkbun";
      };
      portalChain = [
        "identity"
        "security"
        "rate"
        "crowdsec"
      ];
      lanRules =
        action:
        lib.concatMapStringsSep "\n" (
          range:
          ''iifname "${toString cfg.lanInterface}" ip daddr ${toString cfg.lanIPv4} ip saddr ${range} tcp dport 443 ${action}''
        ) cfg.lanIPv4Ranges
        + "\n"
        + lib.concatMapStringsSep "\n" (
          range:
          ''iifname "${toString cfg.lanInterface}" ip6 daddr ${toString cfg.lanIPv6} ip6 saddr ${range} tcp dport 443 ${action}''
        ) cfg.lanIPv6Ranges;
    in
    {
      options.fleet.web = {
        enable = lib.mkEnableOption "commissioned dual-site HTTPS (separate activation/issuance authorization required)";
        exposure = mkOption {
          type = types.enum [
            "public"
            "lan"
          ];
        };
        domain = nullable hostname "Verified shared cookie domain.";
        authHostname = nullable hostname "Verified authentication hostname beneath the cookie domain, identical at both sites.";
        authAddress = nullable (types.strMatching "(100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.[0-9]{1,3}\\.[0-9]{1,3}|fd7a:115c:a1e0:[0-9a-f:]+)") "Verified Racknerd Tailscale IP, identical at both sites; never public DNS.";
        certificateEmail = nullable types.nonEmptyStr "Verified ACME contact.";
        dnsResolvers = mkOption {
          type = types.listOf types.nonEmptyStr;
          default = [ ];
          description = "Verified public recursive DNS host:port endpoints for authoritative DNS-01 propagation checks, not split DNS.";
        };
        productionCertificates = lib.mkEnableOption "separately authorized production ACME issuance after staging";
        lanInterface = nullable (types.strMatching "[a-zA-Z0-9_.:-]+") "Verified Bastion LAN ingress interface.";
        lanIPv4 = nullable ipv4 "Verified Bastion LAN bind address.";
        lanIPv6 = nullable ipv6 "Verified Bastion LAN IPv6 bind address; null explicitly leaves IPv6 HTTPS blocked.";
        lanIPv4Ranges = mkOption {
          type = types.listOf (types.strMatching "[0-9.]+/[0-9]{1,2}");
          default = [ ];
          description = "Verified home IPv4 source ranges.";
        };
        lanIPv6Ranges = mkOption {
          type = types.listOf (types.strMatching "[0-9a-fA-F:]+/[0-9]{1,3}");
          default = [ ];
          description = "Verified home IPv6 source ranges; empty when IPv6 HTTPS is disabled.";
        };
        secrets = lib.genAttrs [ "porkbunApiKey" "porkbunSecretKey" "httpBouncerKey" ] (
          name: nullable types.nonEmptyStr "Declared SOPS secret name for ${name}; not a credential value."
        );
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion =
              cfg.domain != null
              && cfg.authHostname != null
              && lib.hasSuffix ".${toString cfg.domain}" (toString cfg.authHostname);
            message = "Web commissioning requires a real domain and an authentication hostname beneath it.";
          }
          {
            assertion = cfg.authAddress != null && cfg.certificateEmail != null && cfg.dnsResolvers != [ ];
            message = "Web commissioning requires the verified private Authelia IP, certificate contact and public DNS resolvers.";
          }
          {
            assertion =
              cfg.exposure != "lan"
              || (
                cfg.lanInterface != null
                && cfg.lanIPv4 != null
                && cfg.lanIPv4Ranges != [ ]
                && ((cfg.lanIPv6 == null) == (cfg.lanIPv6Ranges == [ ]))
              );
            message = "Bastion HTTPS requires verified LAN interface/address/ranges and an explicit IPv6 policy.";
          }
          {
            assertion = config.services.crowdsec.enable && config.services.crowdsec-firewall-bouncer.enable;
            message = "Commission the independent local CrowdSec engine and firewall bouncer before HTTPS.";
          }
          {
            assertion =
              config.fleet.secrets.ageRecipient != null
              && config.fleet.secrets.ageKeyFile != null
              && lib.all (
                name: secretPath name != "" && lib.hasPrefix "/run/secrets/" (secretPath name)
              ) secretNames;
            message = "Web commissioning requires verified host age custody and all three declared root-owned 0400 runtime SOPS secrets.";
          }
          {
            assertion =
              config.services.tailscale.enable
              && !(builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces);
            message = "Web private transport requires Tailscale without blanket interface trust.";
          }
        ];
        services.traefik = {
          enable = true;
          staticConfigOptions = {
            global = {
              checkNewVersion = false;
              sendAnonymousUsage = false;
            };
            log = {
              level = "WARN";
              format = "json";
            };
            entryPoints = {
              https = entrypoint (if cfg.exposure == "public" then ":443" else "${toString cfg.lanIPv4}:443");
            }
            // lib.optionalAttrs (cfg.exposure == "lan" && cfg.lanIPv6 != null) {
              https6 = entrypoint "[${cfg.lanIPv6}]:443";
            };
            experimental.localPlugins.crowdsec.moduleName = pluginName;
            certificatesResolvers.porkbun.acme = {
              email = toString cfg.certificateEmail;
              storage = "/var/lib/traefik/acme-${
                if cfg.productionCertificates then "production" else "staging"
              }.json";
              caServer =
                if cfg.productionCertificates then
                  "https://acme-v02.api.letsencrypt.org/directory"
                else
                  "https://acme-staging-v02.api.letsencrypt.org/directory";
              dnsChallenge = {
                provider = "porkbun";
                resolvers = cfg.dnsResolvers;
              };
            };
            accessLog = {
              format = "json";
              fields = {
                defaultMode = "drop";
                names = lib.genAttrs [
                  "ClientAddr"
                  "ClientHost"
                  "RequestAddr"
                  "RequestHost"
                  "RequestPath"
                  "RequestMethod"
                  "RequestProtocol"
                  "DownstreamStatus"
                  "DownstreamContentSize"
                  "Duration"
                  "RouterName"
                  "StartUTC"
                ] (_: "keep");
                headers = {
                  defaultMode = "drop";
                  names.User-Agent = "keep";
                };
                queryParameters.defaultMode = "drop";
              };
            };
          };
          dynamicConfigOptions = {
            tls.options.default = {
              minVersion = "VersionTLS12";
              sniStrict = true;
            };
            http = {
              routers.auth = {
                rule = "Host(`${toString cfg.authHostname}`)";
                entryPoints = [ "https" ] ++ lib.optional (cfg.exposure == "lan" && cfg.lanIPv6 != null) "https6";
                service = "auth";
                middlewares = [ "portal" ];
                tls.certResolver = "porkbun";
              };
              services.auth.loadBalancer.servers = [ { url = authURL; } ];
              middlewares = {
                identity.headers.customRequestHeaders = lib.genAttrs [
                  "Remote-User"
                  "Remote-Groups"
                  "Remote-Email"
                  "Remote-Name"
                ] (_: "");
                security.headers = {
                  contentTypeNosniff = true;
                  frameDeny = true;
                  referrerPolicy = "no-referrer";
                  customResponseHeaders.X-Robots-Tag = "noindex, nofollow, noarchive, nosnippet, noimageindex";
                };
                rate.rateLimit = {
                  average = 20;
                  burst = 40;
                  period = "1s";
                };
                crowdsec.plugin.crowdsec = {
                  enabled = true;
                  logLevel = "WARN";
                  crowdsecMode = "stream";
                  streamStartupBlock = true;
                  updateIntervalSeconds = 5;
                  updateMaxFailure = 0;
                  httpTimeoutSeconds = 3;
                  metricsUpdateIntervalSeconds = 0;
                  crowdsecLapiHost = "127.0.0.1:8080";
                  crowdsecLapiScheme = "http";
                  crowdsecLapiKeyFile = "/run/credentials/traefik.service/http-bouncer";
                  crowdsecAppsecEnabled = true;
                  crowdsecAppsecHost = "127.0.0.1:7422";
                  crowdsecAppsecScheme = "http";
                  crowdsecAppsecFailureBlock = true;
                  crowdsecAppsecUnreachableBlock = true;
                  crowdsecAppsecUnreadableBodyBlock = true;
                  forwardedHeadersTrustedIPs = [ ];
                  clientTrustedIPs = [ ];
                };
                authelia.forwardAuth = {
                  address = "${authURL}/api/authz/forward-auth";
                  trustForwardHeader = true;
                  maxResponseBodySize = 8192;
                  authResponseHeaders = [
                    "Remote-User"
                    "Remote-Groups"
                    "Remote-Email"
                    "Remote-Name"
                  ];
                };
                portal.chain.middlewares = portalChain;
                private-app.chain.middlewares = portalChain ++ [ "authelia" ];
              };
            };
          };
        };
        systemd.services.traefik = {
          requires = [
            "crowdsec.service"
            "tailscaled.service"
          ];
          after = [
            "crowdsec.service"
            "tailscaled.service"
          ];
          environment = {
            PORKBUN_API_KEY_FILE = "/run/credentials/traefik.service/porkbun-api";
            PORKBUN_SECRET_API_KEY_FILE = "/run/credentials/traefik.service/porkbun-secret";
          };
          serviceConfig = {
            LoadCredential = [
              "porkbun-api:${secretPath cfg.secrets.porkbunApiKey}"
              "porkbun-secret:${secretPath cfg.secrets.porkbunSecretKey}"
              "http-bouncer:${secretPath cfg.secrets.httpBouncerKey}"
            ];
            BindReadOnlyPaths = [ "${plugins}:/var/lib/traefik/plugins-local" ];
            UMask = "0077";
          };
        };
        environment.persistence."/persist".directories = [
          {
            directory = "/var/lib/traefik";
            user = "traefik";
            group = "traefik";
            mode = "0700";
          }
        ];
        networking.firewall.allowedTCPPorts = lib.optional (cfg.exposure == "public") 443;
        networking.firewall.extraInputRules = lib.mkIf (cfg.exposure == "lan") (lanRules "accept");
        networking.nftables.tables.web-lan = lib.mkIf (cfg.exposure == "lan") {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority -20; policy accept;
              ${lanRules "return"}
              tcp dport 443 drop
            }
          '';
        };
      };
    };
}
