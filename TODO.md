# To do

Work the operator wants done. An item leaves this file in the pull request that finishes it.

- **Checks:** a pull request that changes a host still builds what cache.nixos.org lacks from
  source, since it may not read bastion's cache; make that fast, since `linux` gates every promotion to `main`
  ([CLAUDE.md](CLAUDE.md#branches-and-pull-requests)), and improve the checks themselves.
- **Sandboxes:** tighten the isolation of apps and services, choosing per service between systemd
  sandboxing and a MicroVM.
- **Private runners:** run CI on runners of the fleet's own.
- **Personal project deployments:** automated deployment of personal projects, in the manner of
  Dokploy or Coolify.
- **pr-agent:** run it as a pull request reviewer on the ChatGPT Plus subscription.
- **Automatic server deploys:** servers deploy without the operator running the command.
- **Personal Git instance:** maybe.
- **Workstation ricing:** a better look on the workstations.
- **Secrets:** better handling of secrets, possibly kept in a private repository.
- **Cleanup:** simplify the code for clarity and reuse.
- **MongoDB environment:** a devenv/tack environment with MongoDB.
- **nixos-core:** re-evaluate adopting it; it cannot run beside the etc overlay and userborn.
- **rustic:** replace restic once nixpkgs has a module ([NixOS/nixpkgs#373042](https://github.com/NixOS/nixpkgs/pull/373042)); upstream ships no flake.
- **circus, evix, cade and ncro:** evaluate each.
