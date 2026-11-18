{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-18";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "6d491811023d7af2c96a7fab274935922b29ed01";
    hash = "sha256-XpTGr1XD9qgJKkPSe3nz/A/zM6E+eTpE4mN1l4zbxSw=";
  };
}
