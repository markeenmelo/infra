{
  buildGo127Module,
  fetchFromGitHub,
  lib,
}:
buildGo127Module (finalAttrs: {
  pname = "entire-graph";
  version = "0.6.0";
  src = fetchFromGitHub {
    owner = "entireio";
    repo = "entire-graph";
    tag = "v${finalAttrs.version}";
    hash = "sha256-wUUmn0j3lvLACPqjOZMU6k22S2AO1w1L8pc2iachFsw=";
  };
  proxyVendor = true;
  vendorHash = "sha256-LPkqdo6p2PVB200NSQ9BVqWweDiqowtu07h7uPlF9HI=";
  subPackages = [ "cmd/entire-graph" ];
  ldflags = [
    "-s"
    "-X main.version=v${finalAttrs.version}"
  ];
  # shortcut: upstream tests are not run, enable them once they pass offline in the build sandbox
  doCheck = false;
  meta = {
    description = "Local code intelligence plugin for the Entire CLI";
    homepage = "https://github.com/entireio/entire-graph";
    license = lib.licenses.mit;
    mainProgram = "entire-graph";
  };
})
