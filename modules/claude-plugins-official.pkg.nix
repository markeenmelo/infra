{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-24";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "6985b2d88dc08b4a0d202f5f0301f02e360b9cb1";
    hash = "sha256-4o4BbW198W0HFRLfD22Cld6h2xP2jJj/8kwoql/XH+Y=";
  };
}
