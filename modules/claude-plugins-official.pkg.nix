{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-25";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "0fbfda5a91f4adc311daca25acc99132f40f0b6e";
    hash = "sha256-J9pxacOMDz6wEHJHo5d0JhLfR/95hhJwUz1RmHqRvcI=";
  };
}
