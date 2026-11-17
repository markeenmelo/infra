{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-16";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "fd30cee3ecd5a8ee772733c5d20c0f2bae2da2f0";
    hash = "sha256-EE9iQb8FgWW5Tm7GFI+dVotANVrqTkOoywfsco7Zcgk=";
  };
}
