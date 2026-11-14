{ fetchFromGitHub }:
let
  version = "2.3.1-unstable-2026-11-12";
in
{
  name = "cache-tax-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "karanb192";
    repo = "cache-tax";
    rev = "771b3d8e13d1f7363dce7649dfe9d5e733e157f1";
    hash = "sha256-thkCyv5sRXLTWjQ1Db/yme4hLhxkRBMb/lnLPVhMAPQ=";
  };
}
