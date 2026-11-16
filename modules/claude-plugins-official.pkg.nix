{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-16";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "1d8db0deb7967d5bfb1ff7a851a255cb87b01a85";
    hash = "sha256-GoA8GofinmFt1oeFrX3dq8LdbzBqOJlCwe//UYVcIYw=";
  };
}
