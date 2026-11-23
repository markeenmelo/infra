{ fetchFromGitHub }:
let
  version = "4.2.0-unstable-2026-11-23";
in
{
  name = "caveman-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "b89752f6bca5a26bfde8b019813554241800ca99";
    hash = "sha256-P4mDycyDkmIAnuT4mA68551lfg3YdZiJQMYiOWeg68U=";
  };
}
