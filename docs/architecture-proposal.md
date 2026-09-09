# Architecture proposal (2026-09-09)

Historical proposal accepted for implementation after upstream research; the ADRs and implementation now supersede this dated snapshot.

- flake-parts evaluates a top-level Nixpkgs module configuration. All non-entry-point Nix files are automatically discovered top-level modules. NixOS capabilities live in class-checked `deferredModule` values; host-specific module values are also deferred.
- Typed host metadata selects stable or unstable before `nixosSystem`. Each host owns its package evaluation. No mixed package sets, global overlays or `specialArgs` input forwarding.
- Uncommissioned hosts remain evaluable through `fleetConfigurations`/`fleet`; only explicitly ready hosts appear in `nixosConfigurations` and eligible deploy nodes. A ready flag never bypasses assertions. Synthetic fixtures validate module integration without inventing host facts.
- tmpfs root and persistent Btrfs OS-disk subvolumes avoid scripted initrd rollback hooks and arbitrary partition sizing. Firmware mode, disk identity and ESP size are required. No NAS data topology is included.
- deploy-rs keeps rollback defaults and scopes its overlay to the target package set. Offline desktops opt in. Stable development tooling, evaluation tests and GitHub CI provide a canonical non-destructive check.
