{ fetchFromGitHub }:
let
  version = "2.3.1-unstable-2026-11-17";
in
{
  name = "cache-tax-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "karanb192";
    repo = "cache-tax";
    rev = "535ff33225e666e605e731d78f5ac5efe243c7c3";
    hash = "sha256-+47mWXxkL9n5Z+cgl6FayfybAIt7OL0wvfB352XlQJY=";
  };
}
