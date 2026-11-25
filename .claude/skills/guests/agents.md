# Agents

[agents.nix](../../../modules/agents.nix) runs one guest, `agents`, as `microvm@agents` on
bastion ([microvm.nix](https://microvm-nix.github.io/microvm.nix/) host module, cloud-hypervisor).
The guest is the boundary for unattended agents: its own kernel, no fleet secret, no route to
the LANs or the tailnet's hosts. It is not a `fleet.hosts` entry: it builds inside bastion's
closure. A bastion deploy installs the guest's new system but leaves the running guest alone:
`restartIfChanged` is off, since a nixpkgs or plugin bump changes every store path in its units
and would end every session in it on each update. `agents-restart` restarts it instead, and only
when agents.nix, the shared [_guest.nix](../../../modules/_guest.nix), the operator's login key, or one of its tokens changed since the unit
last ran; anything else, a new Claude Code included, reaches the guest at its next restart. The system a running guest booted stays a garbage-collector
root until then.
`microvm@agents` requires `install-microvm-agents`, which points the guest at its new system:
upstream only orders the two, so a restart could boot the guest before the link moved, into
the previous system. The guest's kernel command line in `microvm@agents`'s log names the system
it booted.

cloud-hypervisor, not QEMU: the QEMU runner opens its disks with io_uring, which
[server.nix](../../../modules/server.nix) disables. It cannot pass systemd credentials, so the
secrets the guest gets come over a read-only virtiofs share. `microvm.vsock.cid` stays unset,
at the cost of an evaluation warning, so the guest has no channel to the host's systemd.

## Disks

The guest's Nix store is a read-only image built with bastion, under a writable overlay, so
`nix build` works inside. `/var/lib/microvms` is the dataset `apps/agents`
([data.nix](../../../modules/hosts/bastion/data.nix)), neither snapshotted nor backed up: work
that matters is pushed. Three images live there: `store.img` (the overlay, deleted before every
start because the guest's Nix database starts empty), `state.img` (`/var/lib`: the tailnet node,
the SSH host key) and `home.img` (`/home`). `/home/agent` is a symlink to `/home/marcos`, left by the
`home-move` unit when the user was renamed, so old absolute paths in tool state still resolve; the
unit runs on every boot and redoes only what an interrupted move left undone. The root is memory and is lost on restart.

## Network

The guest's network and host wiring come from [_guest.nix](../../../modules/_guest.nix), as for
the downloads and hermes guests ([services: arr](../services/arr.md)). Its tap carries a /24 that only
bastion and the guest sit on. The `agents` nftables table drops everything the guest sends to
bastion itself, to any private, CGNAT, link-local or multicast address, to the tailnet interface
and over IPv6, and new connections forwarded towards it, and masquerades the rest to the
internet. The guest resolves through the tailnet's public resolvers. Unlike the other guests it
keeps its journal off the console (`services.journald.settings.Journal.ForwardToConsole` is
forced off), so nothing a process in it logs lands in bastion's journal. `microvm@agents` requires
`nftables.service`, so the guest does not run without the ruleset: a firewall that fails to load
keeps it down, and one that is stopped or restarted takes it along. A switch reloads the ruleset
and leaves the guest alone.

The guest joins the tailnet as `tag:agent`
([main.tf](../../../opentofu/tailscale/main.tf)): admin clients reach its port 22 and the Paseo port, and the tag's one
grant is bastion's port 443, for Grafana: the guest resolves `grafana.DOMAIN` to bastion's
tailnet address through its hosts file. That port is the LAN proxy, which routes by host name,
so the guest reaches the sign-in page of every app it serves; each app's own login is the gate,
except ntfy's `alerts` topic, which needs none ([services: monitoring](../services/monitoring.md)),
and the tailnet policy's tests keep the cache, the state database and bastion's DNS out. Its key is `agents/tailscale-auth-key` in `secrets/hosts/bastion.yaml`,
moved from the `enrollment_keys` output like a host's ([operating: tailnet](../operating/tailnet.md)) and
read once, when `state.img` holds no login, so a refreshed key does not restart the guest.

Two limits of filtering by destination address:

- The home gateway's own WAN address is public, so the guest reaches the gateway there,
  masqueraded as bastion: its DNS, NTP and the sign-in page of its HTTPS interface, which the
  LAN firewall ([opentofu skill](../opentofu/SKILL.md)) admits from bastion for the tailnet's
  admin clients. Accepted: the guest holds no gateway credential.
- A tailnet peer on a home LAN cannot reach the guest directly, so its SSH and Paseo sessions go
  through a relay.

## Access

`ssh marcos@agents` with the operator's login key; `marcos` has no sudo and the guest has no root
login, so a change to the guest is a change to agents.nix. Agent sessions run under Paseo (below).

## Claude

`nixos.claude-agent` in [claude.nix](../../../modules/claude.nix) gives the guest's Claude Code
the caveman, ponytail and cache-tax plugins, Trail of Bits' `insecure-defaults` and
`sharp-edges`, the official `skill-creator` and `claude-md-management`, the language servers,
the rtk hook, and the nixos and Grafana MCP servers, the Grafana one with `--disable-write` and
only the tool groups for what the fleet runs, on `agents/grafana-token`, a Viewer service
account's token. GitHub goes through `gh`, which reads the fresh App token on every call; an MCP
server would read it once and lose GitHub within the hour.
All of it arrives as managed settings and one generated plugin, so nothing depends on the
agent's home. Opus 5.5 is the default model through `ANTHROPIC_MODEL`, which a `--model` Paseo
passes still overrides. caveman and ponytail start at their levels through their environment variables,
which also turns caveman on in headless runs. The guest has no Bash sandbox: the guest itself
is the boundary. The account's connectors stay out.

## Paseo and the other agents

Cursor's CLI (`cursor-agent`) and pi sit beside Claude Code; no other coding agent is installed.
pi is configured through its Home Manager module for `marcos`, in `agent-tools` in
[claude.nix](../../../modules/claude.nix), with install telemetry off and Kimi For Coding's `k3.1-pro` as its starting
model. It gets the same nixos and Grafana MCP servers as Claude Code through
`~/.pi/agent/mcp.json`; what a pi session reads from Grafana, logs with host names, addresses,
user names and request paths included, goes to the provider of the model it runs on.
pi does not read `.claude/skills`, so the repository links `.agents/skills` to it; pi asks once
whether to trust the repository before loading them, and `/trust` keeps the answer in
`~/.pi/agent/trust.json` on `home.img`. The
[Paseo](https://paseo.sh) daemon runs any of them for its desktop, web and mobile clients,
through the module of Paseo's own flake (the `paseo` input) on nixpkgs' package. The daemon runs
as `marcos` with the same tokens a shell gets, written for it at each start to a file only
`marcos` reads, with its relay off (`--no-relay`). It listens on `fleet.paseoPort`, which the
guest's firewall opens on the tailnet interface only and the tailnet policy grants to admin
clients alone ([opentofu skill](../opentofu/SKILL.md)), and asks every client for the daemon
password, `agents/paseo-password` in `secrets/hosts/bastion.yaml`, exported as `PASEO_PASSWORD`
like the tokens below; it may not hold a single quote, and the token script fails the unit, so the daemon does not
start, without it. The phone app connects to `agents` on that port; the desktop app (`paseo-desktop` in
[desktop.nix](../../../modules/desktop.nix)) as a Remote SSH host `ssh://marcos@agents`; a browser through `ssh -N -L 6767:127.0.0.1:6767
marcos@agents` and `http://localhost:6767`. The daemon accepts only `agents`, `localhost` and
IP addresses as host names and refuses a browser origin other than `localhost`, so a web page
cannot drive it. Traffic to it is plain HTTP inside the tailnet's WireGuard. Paseo's state, `~/.paseo`, lives on `home.img`.

## Credentials

Whatever the guest holds, an injected prompt can use or leak. Bastion decrypts the Paseo password,
the Grafana token, the Claude token and pi's three provider keys from `secrets/hosts/bastion.yaml` into the same read-only share as the tailnet key, owned by uid 1000,
the uid of `marcos` in the guest and on bastion ([agents.nix](../../../modules/agents.nix) pins both), and every shell in the guest exports them; a changed token
restarts the guest, through `agents-restart`. The GitHub token is minted on bastion, below.

- `agents/claude-token`: the token from `claude setup-token`, exported
  as `CLAUDE_CODE_OAUTH_TOKEN`. It makes model requests only. `/login` instead would hand the
  guest Remote Control and the account's connectors.
- `agents/{zai,kimi,minimax}-api-key`: pi's keys for the Z.ai Coding Plan, Kimi For Coding and
  MiniMax, exported as `ZAI_API_KEY`, `KIMI_API_KEY` and `MINIMAX_API_KEY`, which pi's built-in
  `zai`, `kimi-coding` and `minimax` providers read. A `/login` credential pi stored in
  `~/.pi/agent/auth.json` wins over these variables; `pi auth logout PROVIDER` drops it. Each is a subscription key that can spend
  that plan's quota; revoke it in that provider's console. For the
  operator's ChatGPT subscription the operator signs pi in once over SSH (`/login`, provider
  `openai-codex`); the session lands in that file on `home.img`, survives restarts, is usable and
  leakable like the keys above, and is revoked from that account's settings.
- `github-token`: a one-hour installation token of the operator's GitHub App, which
  `agents-github-token` on bastion mints from the App's private key (`agents/github-api-key`,
  never in the guest) when the share starts and every 30 minutes. The guest's `gh` wrapper reads
  the file on each call and Git goes through `gh`. The App acts as `NAME[bot]`, not as the
  operator: it holds Contents and Pull requests writes, Issues write for comments in a pull
  request's conversation, and Actions, Checks and Commit statuses reads, never Workflows or
  Administration, and is not a ruleset bypass actor, so the rulesets bind it. It still merges
  whatever the rulesets admit: the changes CLAUDE.md keeps for the operator are a control only
  where a ruleset requires the operator's approval, and otherwise a rule the agent follows, which
  an injected session holding the token can ignore. Contents write still lets a pushed branch
  change the code a pull-request workflow runs, so the App is installed only on repositories
  whose pull-request workflows hold no secret that such code can reach.

Cursor's CLI holds no secret of the repository: the operator signs it in once over SSH
(`cursor-agent login`), and the session lands in `marcos`'s home, `/home/marcos` on `home.img`,
where it survives restarts and is not backed up. It is a whole-account session for that service,
usable and leakable like the tokens above; revoke it from the service's own account page.

Commits made in the guest carry the operator's Git identity, which
[git.nix](../../../modules/git.nix) gives the guest and the workstations alike, and no Claude
attribution, which the managed settings blank.

The share holds nothing else of bastion's. No sops identity, deploy key, build key or cache write
access goes in.
