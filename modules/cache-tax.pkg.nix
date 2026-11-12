{ fetchFromGitHub }:
let
  version = "2.3.1-unstable-2026-11-11";
in
{
  name = "cache-tax-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "karanb192";
    repo = "cache-tax";
    rev = "c4f8cf2faabed12a59a4b1d2aa56d6d8cce43958";
    hash = "sha256-zt0FwUR7yFbKcZsiMz7krc+XNQDDnsCJUjqHKRswzQU=";
  };
}
