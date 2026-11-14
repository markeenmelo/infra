{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-06";
in
{
  name = "entire-skills-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "entireio";
    repo = "skills";
    rev = "11902e22deddf7b867ea1cf958c0220288be4d63";
    hash = "sha256-s/Yod1Xa5V6wifixQ1IFo2zlrOqRwTq0920Y7aGryuY=";
  };
}
