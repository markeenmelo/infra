{ fetchurl }:
let
  version = "5.1.1";
in
{
  pname = "jellyfin-plugin-sso";
  inherit version;
  src = fetchurl {
    url = "https://github.com/K0lin/jellyfin-plugin-sso/releases/download/v${version}/sso-authentication_${version}.zip";
    hash = "sha256-2xJrR2O9o6N1T6IQMjL8A+8b+SnP7aNfLprznIdSM7E=";
  };
}
