{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-19";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "df9699a55c56707e9948a32951ea356638ea8519";
    hash = "sha256-cVfCTknLEP3IJ3GTaL6bLmnNU6Z1UhC0ZjgdvletP6g=";
  };
}
