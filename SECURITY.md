# Security policy

This repository is the whole configuration of a one-operator home fleet. Only `main` is
supported; there are no releases.

## Reporting

Report a vulnerability privately through GitHub's **Report a vulnerability** button on the
Security tab, never in a public issue, pull request or comment. Say what is affected, how to
reproduce it and what it exposes.

## In scope

- What the public edge serves: the Caddy site, the hostnames it forwards and the paths it denies
  ([edge.nix](modules/edge.nix)), and the CrowdSec bans in front of it
  ([crowdsec.nix](modules/crowdsec.nix)).
- Sign-in: the Authelia portal, its access control and OIDC clients
  ([authelia.nix](modules/authelia.nix)), and each app's use of it.
- Remote access: SSH, the deploy account and its sudo rules ([deploy.nix](modules/deploy.nix)),
  Tailscale and the tailnet policy ([opentofu/tailscale](opentofu/tailscale)), and the host
  firewalls.
- Secret handling: anything that would put a plaintext secret, password hash or private key in
  Git, the Nix store or logs, or widen who can decrypt a file under `secrets/`
  ([.sops.yaml](.sops.yaml)).
- The CI workflows under [.github/workflows](.github/workflows), including what pull requests
  from forks can reach.

## Out of scope

- Findings that need the operator's own keys or devices.
- Values under `secrets/`, which are SOPS ciphertext by design.
- Denial of service against the home connection, and upstream bugs in nixpkgs or the apps,
  which go to their own projects.
