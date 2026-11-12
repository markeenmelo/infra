{ fetchFromGitHub }:
let
  version = "4.1.0-unstable-2026-11-09";
in
{
  name = "caveman-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "3dc497a7f858c774d6e15b25e8c6120ef3a0eda8";
    hash = "sha256-I/pMhDvXZp8KOGhWRCNeSIz+3z4ag1m6wdo6kl+JbXs=";
  };
}
