{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-23";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "65adb96f26deb662f6a993f74347d0ccd1a61a52";
    hash = "sha256-DaMrC8WglU3uYxOnl9+7dh+qcpQGtaIF6s5VZWbE6sg=";
  };
}
