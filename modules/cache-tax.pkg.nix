{ fetchFromGitHub }:
let
  version = "2.3.1-unstable-2026-11-16";
in
{
  name = "cache-tax-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "karanb192";
    repo = "cache-tax";
    rev = "2de12deb81db2e88a8411ce9aa8910b04db0de5c";
    hash = "sha256-frFUGNvaCPKX2mG01nVw/lZjrwtktYjWIwDedF1l4Js=";
  };
}
