# Flake-parts evaluation conventions, discovered like every other module.
# flake.nix hands the whole modules/ tree to the pinned import-tree input;
# this file registers the flake-parts extras behind flake.modules options
# and declares the single supported flake system.
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
  systems = [ "x86_64-linux" ];
}
