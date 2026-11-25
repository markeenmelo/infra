{ fetchFromGitHub }:
let
  version = "2.3.1-unstable-2026-11-25";
in
{
  name = "cache-tax-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "karanb192";
    repo = "cache-tax";
    rev = "2ad70fb46aa1aa76eff7b627746040d82919b809";
    hash = "sha256-BSXH91xHxFRa2iYsLbuH7S/bLznyjyunmNUbAiNTLNI=";
  };
}
