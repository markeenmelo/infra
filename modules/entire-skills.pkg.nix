{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-15";
in
{
  name = "entire-skills-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "entireio";
    repo = "skills";
    rev = "af6cd3fce1852a7214c43bbf64315900196ad4ee";
    hash = "sha256-EnAGg7p/wHSUiLYsw6oUWBzEd2C1OxY8M0AX/yzI3x0=";
  };
}
