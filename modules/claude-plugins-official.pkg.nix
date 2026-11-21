{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-21";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "73c8cf3ea7e296057b467990f2f5d61b4c922260";
    hash = "sha256-tG21jUglH8pac5VSDZN7f68vCwThl3GkBOnxz9T9VyE=";
  };
}
