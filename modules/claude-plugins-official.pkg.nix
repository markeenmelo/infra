{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-14";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "b5b01ac4f889fec0c4c6bb89f27ca7c8574473f6";
    hash = "sha256-2rggi6MyrjwIRhM/TCOoDvqlGs4l5V0beE11537mO1Y=";
  };
}
