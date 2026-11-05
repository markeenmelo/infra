{ fetchgit, buildNpmPackage }:
buildNpmPackage {
  name = "vicinae-coffee";
  src = "${
    fetchgit {
      url = "https://github.com/vicinaehq/extensions";
      rev = "0e3953058fb787d2a96e5ac0cec462440c07cd07";
      hash = "sha256-o3+IPlWAp39L+BDR0XUwVeXI5czvcT2NTR9xx+Pi/do=";
      sparseCheckout = [ "/extensions/coffee" ];
    }
  }/extensions/coffee";
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
    cp -r "$(find "$HOME" -path '*/node_modules' -prune -o -type d -path '*/extensions/coffee' -print -quit)" "$out"
    runHook postInstall
  '';
}
