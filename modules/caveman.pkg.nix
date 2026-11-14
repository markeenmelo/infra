{ fetchFromGitHub }:
let
  version = "4.1.0-unstable-2026-11-13";
in
{
  name = "caveman-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "b4ee71d557d96e3cbc14f88fa6e953a1362865f5";
    hash = "sha256-HcNc+iyIL/K4JOBBsJAS2eh0vcpW3CwL5CQMqY0LMh0=";
  };
}
