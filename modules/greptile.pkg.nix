{
  fetchurl,
  lib,
  makeWrapper,
  nodejs,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "greptile";
  version = "3.8.0";
  src = fetchurl {
    url = "https://registry.npmjs.org/greptile/-/greptile-${finalAttrs.version}.tgz";
    hash = "sha512-niUbKwmBFzxdrBevOqf/0g+Tgg3DFwy38DnjranVCCv01bTKTIuSopeO5L8bpl0ycNegIa7lZsQYBHMFBGYFBg==";
  };
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/lib/greptile
    cp -r . $out/lib/greptile
    makeWrapper ${lib.getExe nodejs} $out/bin/greptile --add-flags $out/lib/greptile/dist/greptile.js
  '';
  meta = {
    description = "Greptile code review CLI";
    homepage = "https://greptile.com";
    license = lib.licenses.mit;
    mainProgram = "greptile";
  };
})
