{ fetchFromGitHub }:
let
  version = "0-unstable-2026-11-18";
in
{
  name = "claude-plugins-official-${version}";
  inherit version;
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "e6143c9807a001832badb63e89d58ffe25d542ec";
    hash = "sha256-J6JgsD2V+fAhCLACVcAM/z+60QNuF5W99SzcHkG1g1w=";
  };
}
