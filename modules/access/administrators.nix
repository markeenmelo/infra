let
  thinkpadSecrets = ../../secrets/hosts/thinkpad.yaml;
  administratorKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgH8hFXLCNPpNUWvohvn5y0S+KGtEIFs0gIj6ihV5PC"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAYdnogT40vOG0eZn4guvWq33q6VANCYXEYsxOSIsVbc"
  ];
  recipients = [
    "age1vxf38fcnxh2v5razwzrlknljxja76jnt9gxxvnjwrun29h5cgymq297mht"
    "age1uyv2jhru0fyy63ae3rwvzx4gzd42k8v0hl2rvjpaz6fqr5qhs5fshqat7p"
  ];
in
{
  flake.modules.nixos.base.fleet.access.authorizedKeys = administratorKeys;

  fleet.hosts.thinkpad.module = { config, lib, ... }: {
    fleet.access = {
      admin = "marcos";
      passwordSecrets.marcos = "marcos-password-hash";
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
