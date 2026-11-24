{ fetchFromGitHub }:
let
  version = "4.2.0-unstable-2026-11-24";
in
{
  name = "caveman-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "47c61be2d10a354f0c5cbe2b90959d24c06b16c6";
    hash = "sha256-eQioS8/CUPiXnkTzada7pWO4cu/Ru9Hfzi6xmdULxO0=";
  };
}
