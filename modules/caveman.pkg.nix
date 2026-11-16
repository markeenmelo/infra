{ fetchFromGitHub }:
let
  version = "4.1.0-unstable-2026-11-16";
in
{
  name = "caveman-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    rev = "9b243662ff98d392bc0a95b865a554583d71be75";
    hash = "sha256-1X2DjYa4xqO1ZqwxdFjCmaypp0+HYncEpXaut4i9LkE=";
  };
}
