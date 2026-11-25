{
  flake.modules.nixos.fwupd =
    { config, lib, ... }:
    let
      efi = "/run/fwupd-efi/fwupdx64.efi";
    in
    {
      services.fwupd = {
        enable = true;
        uefiCapsuleSettings.DisableShimForSecureBoot = true;
      };

      systemd.services.fwupd-efi-sign = {
        description = "Sign fwupd's EFI app with the Secure Boot keys";
        wantedBy = [ "fwupd.service" ];
        before = [ "fwupd.service" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        unitConfig.RequiresMountsFor = [ "/var/lib/sbctl" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${lib.getExe config.boot.loader.limine.secureBoot.sbctl} sign -o ${efi}.signed ${efi}";
        };
      };

      preservation.preserveAt."/persist".directories = [ "/var/lib/fwupd" ];
    };
}
