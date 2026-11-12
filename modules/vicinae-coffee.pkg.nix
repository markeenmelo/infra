{ fetchgit, buildNpmPackage }:
buildNpmPackage (finalAttrs: {
  pname = "vicinae-coffee";
  version = "0-unstable-2026-11-04";
  src = fetchgit {
    url = "https://github.com/vicinaehq/extensions";
    rev = "181904331f5289b53ee3443f98cfa5441d399f35";
    hash = "sha256-o3+IPlWAp39L+BDR0XUwVeXI5czvcT2NTR9xx+Pi/do=";
    sparseCheckout = [ "/extensions/coffee" ];
  };
  sourceRoot = "${finalAttrs.src.name}/extensions/coffee";
  npmDepsHash = "sha256-z+X3SYqkJyEqV1kX/0owm56t5uocE62kTeLTDnKaWc8=";
  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  preBuild = ''
    mkdir -p "$TMPDIR/bin"
    printf '#!/bin/sh\n' > "$TMPDIR/bin/open"
    chmod +x "$TMPDIR/bin/open"
    export PATH="$TMPDIR/bin:$PATH"
  '';
  installPhase = ''
    runHook preInstall
    cp -r "$(find "$HOME" -path "$PWD" -prune -o -path '*/node_modules' -prune -o -type d -path '*/extensions/coffee' -print -quit)" "$out"
    runHook postInstall
  '';
})
