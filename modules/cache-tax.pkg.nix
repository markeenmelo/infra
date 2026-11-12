{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-08";
in
{
  name = "cache-tax-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "karanb192";
    repo = "cache-tax";
    rev = "b05ec14e8d327021ade8c4969003547be8076812";
    hash = "sha256-De1wDZFSgUeuAphM9k5xhaRMTAgLMPs1UC1t7UDTCSY=";
  };
}
