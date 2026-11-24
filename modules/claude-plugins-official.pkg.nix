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
    rev = "5cec6716767283f4675a05f5f8855b5b49c81783";
    hash = "sha256-RgRJXQWhAUkCM0xNrJt2WVwkN47JV005CF8IK9wMZhg=";
  };
}
