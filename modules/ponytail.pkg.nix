{ fetchFromGitHub }:
let
  version = "5.3.3-unstable-2026-10-29";
in
{
  name = "ponytail-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "96608e078b2d5ea607c5c3b8b5a54d1c1fba6846";
    hash = "sha256-PhPtZbeX2wBp19GtWRy+fV93+fFYZe5S487eXPDl/us=";
  };
}
