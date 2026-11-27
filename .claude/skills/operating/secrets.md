# Secrets

Only ciphertext enters Git; `.sops.yaml` owns the recipients, one exact rule per file. Claude
never decrypts or edits a secret: it names the file, key and command and the operator runs it in a
private terminal ([CLAUDE.md](../../../CLAUDE.md#autonomy)).

**Never** paste a decrypted or generated value into chat, a command argument or Nix; commit editor
backups of decrypted files; or add a plaintext placeholder to make a build pass. Removing
ciphertext or a recipient revokes nothing already in Git history: a lost or exposed identity means
rotating every value its files held.

## Identities

- **Operator**: the age key in `~/.config/sops/age/keys.txt` (`&operator`).
- **Hosts**: derived from the SSH host key, `ssh-to-age <<< "$(cat /etc/ssh/ssh_host_ed25519_key.pub)"`.
  [secrets.nix](../../../modules/secrets.nix) reads `/persist/etc/ssh/ssh_host_ed25519_key`
  directly, since activation decrypts before tmpfiles links `/etc/ssh`. A reinstall keeps the key: the
  `install` app carries `/persist/etc/ssh` over ([deploy.md](deploy.md#install)); a new key is a new
  recipient and `sops updatekeys` on every file whose rule names the host.

## Files

| File | Recipients | Keys |
|---|---|---|
| `shared/login.yaml` | operator, bastion, thinkpad, beast | `marcos-password-hash` (`operator-login` in [access.nix](../../../modules/access.nix)): one password for `marcos`'s login and sudo on bastion and the workstations; edge has no `marcos` and is not a recipient, so the public host never holds the hash |
| `hosts/HOST.yaml` | operator, HOST | `tailscale-auth-key` ([tailnet.md](tailnet.md)); on bastion also `authelia/{jwt,storage,smtp-password,USER-email,USER-password-hash,oidc-hmac,oidc-signing-key,ID-client-secret-hash}` ([services: identity](../services/identity.md)) and each OIDC app's `APP/oidc-client-secret`, Grafana's `grafana/{secret-key,admin-password,heartbeat-url}` and ntfy's `ntfy/{publisher-hash,publisher-token}` ([services: monitoring](../services/monitoring.md)), Jellyfin's `jellyfin/{api-key,password,ian-password}` ([services: jellyfin](../services/jellyfin.md)), the arr apps' `arr/{sonarr,radarr,prowlarr}-api-key`, `arr/{sonarr,radarr}-oidc-client-secret`, `arr/password`, `arr/qbittorrent-password{,-hash}`, the Private Internet Access account `pia/{username,password}`, `arr/sabnzbd-{api,nzb}-key`, `arr/{newshosting,tweaknews}-username`, `arr/newshosting-password`, `arr/easynews-{password,api-key}` and `arr/{ninjacentral,nzbgeek,althub}-api-key`, `arr/seerr-api-key` ([services: arr](../services/arr.md)), the restic password `backups/restic-password` and pCloud's rclone config `backups/rclone-pcloud` ([backups skill](../backups/SKILL.md)), the camera stream URLs `frigate-main`, `frigate-sub` ([services: frigate](../services/frigate.md)), and the cache signing key `harmonia-sign-key`, whose public half is `cacheKey` in [builder.nix](../../../modules/builder.nix), trusted by every workstation ([deploy.md](deploy.md)), and per exit node `vpn-exit/{ca,us,br}-auth-key` ([tailnet.md](tailnet.md)), and the agent MicroVM's `agents/{tailscale-auth-key,github-api-key,claude-token,paseo-password,grafana-token,zai-api-key,kimi-api-key,minimax-api-key}` (`github-api-key` is the GitHub App's private key, which stays on bastion) ([guests: agents](../guests/agents.md)) and the Hermes MicroVM's `hermes/{env,auth}` ([guests: hermes](../guests/hermes.md)), and Dorian's `dorian/token` ([services: dorian](../services/dorian.md)) |
| `hosts/thinkpad.yaml` | operator, thinkpad | `tailscale-auth-key`, `wifi-psk` (MN-Home), `seneca/{identity,password}` (SenecaNET's WPA2-Enterprise profile), `nix-build-ssh-key` ([hosts: thinkpad](../hosts/thinkpad.md)) |
| `hosts/beast.yaml` | operator, beast | `tailscale-auth-key` only: wired, no `wifi` module, and it builds itself ([hosts: beast](../hosts/beast.md)) |
| `hosts/inspiron.yaml` | operator, inspiron | `tailscale-auth-key`, `kids-wifi-psk` (MN-Kids's passphrase, also in `unifi/operator.yaml`), and its own `marcos-password-hash`, a password unlike the fleet's so the least-protected laptop never holds the hash that opens sudo elsewhere ([hosts: inspiron](../hosts/inspiron.md)) |
| `shared/github.yaml` | operator, thinkpad, beast | `nix-access-tokens`, one nix.conf line `access-tokens = github.com=TOKEN` holding a classic personal access token with `repo` scope, so evaluation and `tack update` read private repositories, including ones the operator only contributes to, and get the authenticated GitHub rate limit ([github-token.nix](../../../modules/github-token.nix)); it lands in `marcos`'s user nix.conf, never the system one, which the `deploy` account's Nix also reads, and `marcos`'s session sets `TACK_NIX_CONF_TOKENS=1`, so every tack command reads it too. The agent guest does not hold it, so a private pin does not evaluate there |
| `shared/crowdsec.yaml` | operator, bastion, edge | `edge-bouncer-key`, which only reads ban decisions: bastion registers it, the edge's bouncer uses it ([proxy skill](../proxy/SKILL.md)) |
| `tailscale/operator.yaml` | operator | Tailscale OAuth client, tailnet name, state passphrase ([opentofu skill](../opentofu/SKILL.md)) |
| `porkbun/api.yaml` | operator, bastion | `PORKBUN_API_KEY`, `PORKBUN_SECRET_KEY` for bastion's DNS-01 ([proxy skill](../proxy/SKILL.md)) and the `tofu` app |
| `porkbun/operator.yaml` | operator | state passphrase for the DNS records; the app adds `api.yaml` ([opentofu skill](../opentofu/SKILL.md)) |
| `oracle/operator.yaml` | operator | `TF_VAR_tenancy_ocid`, `TF_VAR_user_ocid`, `TF_VAR_fingerprint`, `TF_VAR_private_key` (the API signing key, PEM), `TF_VAR_region` (the home region), `TF_VAR_alert_email` (where the spend alert goes), state passphrase ([opentofu skill](../opentofu/SKILL.md)); the `wake` app starts an instance with the same key ([wake.nix](../../../modules/wake.nix)) |
| `unifi/operator.yaml` | operator | `UNIFI_API_KEY` for the gateway, the Wi-Fi passphrases by SSID, state passphrase ([opentofu skill](../opentofu/SKILL.md)) |

`agents/claude-token` in `hosts/bastion.yaml` is Claude Code's sign-in for the agent guest
([guests: agents](../guests/agents.md)), the token from `claude setup-token`. It makes model requests only, so the guest has no Remote Control
and none of the account's connectors, and one revocation signs it out.

## Delivery

Declare `sops.secrets.NAME` beside its consumer, with `sopsFile` only when it is not the host's own
`hosts/HOST.yaml` (the default, set in [secrets.nix](../../../modules/secrets.nix)), `key` when the SOPS path differs,
`neededForUsers` for a password hash and `restartUnits` for every reader. Delivery is root-owned
0400, or owned by `marcos` for a tool that account runs (asserted in [secrets.nix](../../../modules/secrets.nix)); a unit reads through
`LoadCredential` or the upstream module's `*File` option. A unit that needs a file in its own
format gets a `sops.templates` entry rendered from `sops.placeholder`, so the secrets it
references stay declared; the template is delivered the same way. Secrets and templates are
written by the activation script before any unit starts, so units need no ordering on them.

## Editing

```sh
sops edit secrets/shared/login.yaml        # change values; keep keys and recipients
sops updatekeys -y secrets/shared/login.yaml  # after a .sops.yaml rule change
```

Ciphertext edit and consumer declaration land in the same commit. The `secrets` check fails on a
non-sops file under `secrets/`, a plaintext value inside one, a file whose recipients differ from
its `.sops.yaml` rule, and secret material anywhere in the tree.

## New host

1. Operator shares the host's age recipient (above).
2. Add the anchor and an exact `hosts/HOST.yaml` rule to `.sops.yaml`; add the host to each shared
   rule whose file it reads.
3. Operator runs `sops updatekeys -y` on those shared files and `sops edit` for the host file.
