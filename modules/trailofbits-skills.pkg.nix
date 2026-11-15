{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-12";
in
{
  name = "trailofbits-skills-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "trailofbits";
    repo = "skills";
    rev = "149d7b21f4067765b82e67029730b42d228ef4b4";
    hash = "sha256-8NBnk9sFW1IMkd+qmTvLKweh3CkeJaALEZBLs3GaxlM=";
  };
}
