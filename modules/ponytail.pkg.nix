{ fetchFromGitHub }:
let
  version = "5.3.3-unstable-2026-11-22";
in
{
  name = "ponytail-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "ebd8654c2c627f721eb8f9c0d1bd4090a29f9e10";
    hash = "sha256-5m6JW3U6EMYUg4YVLh7nRRTWGY3shrFQ0wK0bediVFc=";
  };
}
