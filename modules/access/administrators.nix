{ lib, ... }:
let
  sharedPassword = ../../secrets/shared/marcos-password.yaml;
  # Reviewed public policy only. The built check compares the actual YAML
  # recipients; Nix never parses or decrypts password material.
  recipients = [
    "age1vxf38fcnxh2v5razwzrlknljxja76jnt9gxxvnjwrun29h5cgymq297mht"
    "age15r7mf8n0ah32y9xf8jxjvj4yrzsf3y52cucqeyr6hlxtkw63vs0qjz7wgm"
    "age1dpxn0ymj6jyt33yf9ukuekwh93w8r3gsmfx8d3g3g3vhh5dn7ygsdpy48t"
    "age1p0ecx9y4vn85nccz98427qpfyxfva5kfg9vr6ccqammscuwl0vfsh7rrkf"
  ];
in
{
  # Explicit shared account/password policy; host identities remain distinct.
  # This public SSH key was read from each installed host and selected for reuse.
  fleet.hosts = lib.genAttrs [ "thinkpad" "racknerd" "bastion" ] (_: {
    module = { config, lib, ... }: {
      fleet = {
        access = {
          admin = "marcos";
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYdnogT40vOG0eZn4guvWq33q6VANCYXEYsxOSIsVbc"
          ];
          passwordSecrets.marcos = "marcos-password-hash";
          passwordlessSudo = false;
        };
        bootstrap.missing =
          lib.optional (!(lib.elem config.fleet.secrets.ageRecipient recipients))
            "Verify fleet.secrets.ageRecipient and include it in the shared marcos password recipient policy and YAML before commissioning.";
      };
      # Missing identity/recipient means no secret declaration: access keeps
      # the unactivated candidate account locked instead of inventing a key.
      sops.secrets =
        lib.mkIf
          (config.fleet.secrets.ageKeyFile != null && lib.elem config.fleet.secrets.ageRecipient recipients)
          {
            marcos-password-hash = {
              sopsFile = sharedPassword;
              neededForUsers = true;
            };
          };
      users.users.marcos.uid = 1000;
    };
  });

  perSystem = { pkgs, ... }: {
    checks.shared-password-recipients =
      pkgs.runCommand "shared-password-recipients"
        {
          nativeBuildInputs = [
            pkgs.yq-go
            pkgs.jq
          ];
        }
        ''
          set -euo pipefail
          yq -o=json '.sops.age | map(.recipient) | sort' ${sharedPassword} |
            jq -e --argjson expected '${builtins.toJSON (lib.sort builtins.lessThan recipients)}' \
              '. == $expected' >/dev/null
          touch "$out"
        '';
  };
}
