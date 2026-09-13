{ lib, ... }:
let
  thinkpadSecrets = ../../secrets/hosts/thinkpad.yaml;
  administratorKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgH8hFXLCNPpNUWvohvn5y0S+KGtEIFs0gIj6ihV5PC"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYdnogT40vOG0eZn4guvWq33q6VANCYXEYsxOSIsVbc"
  ];
  recipients = [
    "age1vxf38fcnxh2v5razwzrlknljxja76jnt9gxxvnjwrun29h5cgymq297mht"
    "age15r7mf8n0ah32y9xf8jxjvj4yrzsf3y52cucqeyr6hlxtkw63vs0qjz7wgm"
  ];
in
{
  fleet.hosts = lib.mkMerge [
    (lib.genAttrs [ "thinkpad" "racknerd" "bastion" ] (_: {
      module.fleet.access.authorizedKeys = administratorKeys;
    }))
    {
      thinkpad.module = { config, lib, ... }: {
        fleet = {
          access = {
            admin = "marcos";
            passwordSecrets.marcos = "marcos-password-hash";
            passwordlessSudo = false;
          };
          bootstrap.missing =
            lib.optional (!(lib.elem config.fleet.secrets.ageRecipient recipients))
              "Verify fleet.secrets.ageRecipient and include it in the ThinkPad password recipient policy and YAML before commissioning.";
        };
        sops.secrets =
          lib.mkIf
            (config.fleet.secrets.ageKeyFile != null && lib.elem config.fleet.secrets.ageRecipient recipients)
            {
              marcos-password-hash = {
                sopsFile = thinkpadSecrets;
                neededForUsers = true;
              };
            };
        users.users.marcos.uid = 1000;
      };
    }
  ];
}
