{ inputs, ... }:
{
  flake.modules.homeManager.base =
    { config, ... }:
    {
      home.sessionVariables.SOPS_AGE_KEY_FILE = "${config.xdg.configHome}/sops/age/keys.txt";
    };

  flake.modules.darwin.base =
    { config, ... }:
    {
      imports = [ inputs.sops-nix.darwinModules.sops ];
      sops = {
        defaultSopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
        age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      };
    };

  flake.modules.nixos.base =
    { config, lib, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];
      sops = {
        defaultSopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
        age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
      };
      assertions = lib.concatLists (
        lib.mapAttrsToList (
          kind: entries:
          lib.mapAttrsToList (name: entry: {
            assertion =
              entry.mode == "0400"
              && lib.elem entry.owner [
                null
                "marcos"
              ]
              && entry.group == null
              && entry.uid == 0
              && entry.gid == 0;
            message = "sops.${kind}.${name} must keep the root-owned 0400 default, or belong to marcos for a tool that account runs; a unit reads it through LoadCredential or a *File option.";
          }) entries
        ) { inherit (config.sops) secrets templates; }
      );
    };

  perSystem =
    { lib, pkgs, ... }:
    {
      checks.secrets = pkgs.runCommand "secrets" { } ''
        cd ${inputs.self}
        while IFS= read -r -d "" f; do
          case $f in *.yaml) ;; *) echo "secrets/ holds only sops yaml: $f" >&2; exit 1 ;; esac
          grep -q '^    mac: ENC\[' "$f" || { echo "not sops ciphertext: $f" >&2; exit 1; }
          leaves=$(${lib.getExe pkgs.yq-go} 'del(.sops) | .. | select(tag != "!!map" and tag != "!!seq")' "$f")
          printf '%s' "$leaves" | grep -qvE '^ENC\[' && { echo "plaintext value in $f" >&2; exit 1; }
        done < <(find secrets ! -type d ! -path secrets/README.md -print0)
        status=0
        ${lib.getExe pkgs.gnugrep} -rIlE \
          -e 'AGE-SECRET-KEY-1[0-9A-Z]{58}' \
          -e 'BEGIN( [A-Z]+)* PRIVATE KEY( BLOCK)?-{5}' \
          -e 'gh[pousr]_[A-Za-z0-9]{36}' \
          -e 'github_pat_[A-Za-z0-9_]{22,}' \
          -e 'tskey-[a-z]+-[A-Za-z0-9]+-[A-Za-z0-9]+' \
          -e 'sk-(ant|proj)-[A-Za-z0-9_-]{20,}' \
          -e '[ps]k1_[A-Za-z0-9]{32,}' \
          -e 'eyJ[A-Za-z0-9_-]{8,}\.eyJ' \
          -e '\$(y|7|6|5|2[abxy]|argon2(id|i|d)|pbkdf2(-sha[0-9]+)?|scrypt)\$[./A-Za-z0-9+=,$-]{20,}' \
          . || status=$?
        [ "$status" -eq 1 ] || { echo "secret material in the tree, or grep failed" >&2; exit 1; }
        touch $out
      '';
    };
}
