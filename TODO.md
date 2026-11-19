# To do

Work the operator wants done. An item leaves this file in the pull request that finishes it.

- **Checks:** make `check.yml` fast enough for agents to wait for it on every pull request
  ([CLAUDE.md](CLAUDE.md#branches-and-pull-requests)), and improve the checks themselves.
- **Sandboxes:** tighten the isolation of apps and services, choosing per service between systemd
  sandboxing, a MicroVM and jail.nix.
- **Private runners:** run CI on runners of the fleet's own.
- **Personal project deployments:** automated deployment of personal projects, in the manner of
  Dokploy or Coolify.
- **pr-agent:** run it as a pull request reviewer on the ChatGPT Plus subscription.
- **Automatic server deploys:** servers deploy without the operator running the command.
- **CVE scanning:** better than the weekly vulnix run.
- **Personal Git instance:** maybe.
- **Workstation ricing:** a better look on the workstations.
- **Cleanup.**
