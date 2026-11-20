{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-20";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "d7d32797e7e02708d0bb00ffe8b8f2397dc1aea6";
    hash = "sha256-NBpp0gP79bm8YL1FL357oYsoLp+MtjN/rzAtuqQ7mg4=";
  };
}
