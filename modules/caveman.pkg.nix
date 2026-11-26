{ fetchFromGitHub }:
let
  version = "4.2.0-unstable-2026-11-26";
in
{
  name = "caveman-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "e74a11ccdb38b98d15c9f9545787c907dd15f0ab";
    hash = "sha256-CsrSd7i/6+wkGAIDa29KpkYaaJgzhRhAGNnbEFgJ9Fk=";
  };
}
