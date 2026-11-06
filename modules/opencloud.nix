{ config, lib, ... }:
let
  inherit (config.fleet) domain;
  port = 9200;
  root = "/srv/opencloud";
  hostname = "cloud.${domain}";
  scopes = [
    "openid"
    "offline_access"
    "groups"
    "profile"
    "email"
  ];
  clients = {
    web = [
      "https://${hostname}/"
      "https://${hostname}/oidc-callback.html"
      "https://${hostname}/oidc-silent-redirect.html"
    ];
    OpenCloudDesktop = [
      "http://127.0.0.1"
      "http://localhost"
    ];
    OpenCloudAndroid = [ "oc://android.opencloud.eu" ];
    OpenCloudIOS = [
      "oc://ios.opencloud.eu"
      "oc.ios://ios.opencloud.eu"
    ];
  };
in
{
  flake.modules.nixos.opencloud =
    { pkgs, ... }:
    {
      services.opencloud = {
        enable = true;
        package = pkgs.opencloud-production;
        address = "0.0.0.0";
        inherit port;
        url = "https://${hostname}";
        stateDir = root;
        environment = lib.mkMerge [
          {
            OC_INSECURE = "false";
            PROXY_TLS = "false";
            OC_CONFIG_DIR = "${root}/config";
            OC_OIDC_ISSUER = "https://auth.${domain}";
            OC_EXCLUDE_RUN_SERVICES = "idp";
            PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD = "jwt";
            PROXY_OIDC_REWRITE_WELLKNOWN = "true";
            PROXY_AUTOPROVISION_ACCOUNTS = "true";
            PROXY_AUTOPROVISION_CLAIM_USERNAME = "preferred_username";
            PROXY_AUTOPROVISION_CLAIM_EMAIL = "email";
            PROXY_AUTOPROVISION_CLAIM_DISPLAYNAME = "name";
            PROXY_AUTOPROVISION_CLAIM_GROUPS = "groups";
            PROXY_ROLE_ASSIGNMENT_DRIVER = "oidc";
            PROXY_ROLE_ASSIGNMENT_OIDC_CLAIM = "groups";
            GRAPH_ASSIGN_DEFAULT_USER_ROLE = "false";
            WEB_OIDC_SCOPE = toString scopes;
            PROXY_CSP_CONFIG_FILE_LOCATION = toString (
              pkgs.writeText "opencloud-csp.yaml" (
                builtins.toJSON {
                  directives = lib.genAttrs [ "connect-src" "frame-src" "script-src" ] (_: [
                    "https://auth.${domain}/"
                  ]);
                }
              )
            );
          }
          (lib.genAttrs' [ "WEB" "DESKTOP" "ANDROID" "IOS" ] (
            client: lib.nameValuePair "WEBFINGER_${client}_OIDC_CLIENT_SCOPES" (toString scopes)
          ))
        ];
      };
      fleet = {
        web.apps.cloud = {
          inherit port;
          public = true;
          denied = [
            "method POST PATCH DELETE\n  path /graph/v1.0/users /graph/v1.0/users/* /graph/v1.0/groups /graph/v1.0/groups/* /graph/v1.0/education /graph/v1.0/education/*"
            "path /api/v0/settings/assignments-add /api/v0/settings/assignments-remove /admin-settings /admin-settings/*"
          ];
        };
        oidc.clients = lib.mapAttrs (_: redirect_uris: {
          public = true;
          client_name = "OpenCloud";
          inherit redirect_uris scopes;
          response_types = [ "code" ];
          grant_types = [
            "authorization_code"
            "refresh_token"
          ];
          access_token_signed_response_alg = "RS256";
          userinfo_signed_response_alg = "none";
        }) clients;
      };
      systemd.services = {
        opencloud-init-config = {
          unitConfig.RequiresMountsFor = root;
          serviceConfig = {
            ExecStartPre = [
              "+${pkgs.coreutils}/bin/install -d -o opencloud -g opencloud -m 0750 ${root} ${root}/config ${root}/idm"
            ];
            ReadWritePaths = [ "${root}/config" ];
          };
        };
        opencloud = {
          requires = [ "opencloud-init-config.service" ];
          unitConfig.RequiresMountsFor = root;
        };
      };
    };
}
