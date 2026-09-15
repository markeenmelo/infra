---
name: reverse-proxy
description: Commission gated Racknerd/Bastion Traefik, central Authelia MFA, local CrowdSec and isolated encrypted Porkbun OpenTofu; prepare the separate Tailscale-only OpenSSH cutover.
---

# Dual-site web foundation

Read [AGENTS.md](../../../AGENTS.md), [secrets](../../../secrets/README.md), [storage](../storage/SKILL.md), [Tailscale](../tailscale/SKILL.md) and [deploy](../deploy/SKILL.md). Run from the repository root in the locked shell. This procedure grants no operational permission. Secret provisioning/decryption, DNS writes, issuance, enrollment, policy apply, activation, mounting, fault injection and reboot each require separate authorization. Never test a ban against the only management client. NAS data, split DNS, ThinkPad and OS disks are outside this concern.

## Boundaries and gates

| Gate | Default | Effect after separately authorized activation |
|---|---|---|
| `services.crowdsec.enable` | false | Each server's independent local engine, AppSec and port-scoped firewall bouncer; permits preparing HTTP bouncer registration before web exposure |
| `fleet.web.enable` | false | Traefik HTTPS and, only on Racknerd, the whole central Authelia instance; incomplete facts/secrets fail assertions |
| `fleet.web.productionCertificates` | false | Staging ACME by default; separate production store/account after successful staging and issuance authorization |
| `fleet.sshTailnetOnly` | false | Separately verified SSH cutover, independent of both web gates |

Fill actual facts in the owning concern, not host import roots. `fleet.web` needs the same verified `domain`, `authHostname` and Racknerd `authAddress` at both sites, plus `certificateEmail` and public `dnsResolvers` (host:port). Tailscale address types exclude public/LAN ranges but do not establish node identity. Bastion also needs `lanInterface`, `lanIPv4`, `lanIPv4Ranges` and an explicit IPv6 choice: null `lanIPv6` with empty `lanIPv6Ranges` blocks IPv6 HTTPS, otherwise supply both verified values. Never infer these from the old deploy address. Review both families and console access before any activation.

The operator confirmed Bastion's DHCP reservation for `192.168.2.2` and Racknerd's public IPv4 `72.11.150.242` (already the deploy endpoint). No user-created DNS records have been reported; still inspect the Porkbun inventory for registrar defaults before defining records. Public DNS-01 resolvers remain unselected.

Racknerd's `fleet.authentication` additionally needs `bastionAddress` and the secret selections below. `notifier` defaults explicitly to `"filesystem"` for temporary operator-mediated enrollment; SMTP is not required in this mode. Authelia writes only the latest notification to `/run/authelia-main/notifications.txt` (`0600`, under a service-owned systemd runtime directory with mode `0700`). The pinned notifier overwrites the file on each message and clears it during its startup check; stopping/restarting the service or rebooting loses it. No email is sent, and this file is not persisted or backed up.

After separately authorized activation, use a private operator terminal with verified Racknerd access to read the file as root. Check the intended recipient and handle one enrollment at a time; each link is a secret. Do not expose the file through HTTP, broaden permissions, paste its contents into chat/logs/Git or treat filesystem access as proof of email ownership. For another user, verify identity independently and deliver only their link privately. This is a temporary manual workflow, not unattended notification delivery.

To migrate later, select `notifier = "smtp"` and supply verified `smtpAddress`, `smtpUsername`, `smtpSender` and `secrets.smtpPassword`. Verify the endpoint, sender authorization and TLS certificate; `smtp://` requires STARTTLS, `submissions://` uses implicit TLS. SMTP mode has no filesystem fallback. Startup checks stay enabled in both modes. No fake users, password-only fallback or default app permission is provided.

Only the exact authentication portal has a router. Future private apps must add explicit hostname/TLS routers using `private-app`, actual backends with verified upstream certificates and explicit Authelia `two_factor` ACL rules. The ACL defaults to deny. Review direct backend reachability separately; middleware does not protect a bypass port. No wildcard app route, discovery, dashboard, public HTTP or HTTP/3 is enabled.

The chain is identity-header removal → security/no-index headers → per-client rate limiting → local CrowdSec/AppSec → Authelia ForwardAuth. The portal omits only the last step. The four recognized identity headers (`Remote-User`, `Remote-Groups`, `Remote-Email`, `Remote-Name`) are removed and only these approved Authelia response headers are trusted by backends. Do not introduce another identity header without sanitizing it. Entrypoints trust no forwarded headers and enable no PROXY protocol. `trustForwardHeader` on the inner ForwardAuth hop consumes Traefik's sanitized headers, not trusted visitor input. Access-log `ClientHost` and bouncer IP extraction must be verified with forged forwarding headers during commissioning.

Both portal and ForwardAuth use the central Tailscale IP directly, never public/split DNS. Home authorization depends on Racknerd and the link even with an existing cookie; outages must deny protected requests. Authelia uses one file-backed directory, SQLite MFA data and in-memory sessions; restarts invalidate sessions. Cookies use Authelia's native Secure/HttpOnly behavior, SameSite Lax, 5m inactivity, 1h expiration and no remember-me. WebAuthn/TOTP are enabled. Password change/reset APIs are disabled because the SOPS user file is read-only; update password hashes privately through SOPS. Never create enrollment material in Git.

## Private transport and later SSH cutover

The current tailnet policy and deploy endpoints are intentionally unchanged. Before web activation:

1. Verify both server node IDs, ownership, tags and Tailscale IPs through authorized inventory, preserving existing identities. Verify Racknerd `authAddress` is its actual address and `bastionAddress` is the actual source used by Bastion's direct connection (including address-family selection).
2. In `assets/tailscale/policy.hujson`, add only the exact Bastion IP → Racknerd IP TCP 9091 grant. Add an allow test for that pair/port, and denials for the verified ordinary users/admin clients/other server sources and unrelated ports. Do not substitute a `tag:server` → `tag:server` grant. Retain current TCP 22 grants/tests and unrelated denials. Native policy validation and applying the saved tailnet plan follow the Tailscale skill with their own authorization.
3. Racknerd's early inet input chain permits 9091 only from loopback or that Bastion source on `tailscale0`. The listener binds only the supplied Racknerd Tailscale IP. Absence of the address prevents binding; there is no public fallback. Prove reachability from Bastion and denial elsewhere, not merely an active daemon.

For SSH, first prove all authorized administrators and deploy-rs over verified Tailscale endpoints, trusted existing host keys, noninteractive sudo, rollback and an independently usable console. Supply Racknerd's real private endpoint in `modules/deploy.nix` and deploy that endpoint change **while old SSH access remains**. Bastion already uses its configured MagicDNS endpoint. Separately authorize closing SSH on one host at a time, then set `fleet.sshTailnetOnly = true` for that host. The gate disables OpenSSH's blanket firewall opening, permits 22 specifically on `tailscale0`, and drops non-loopback TCP 22 outside it at inet priority -30, before established-flow accepts, for IPv4 and IPv6. Tailscale SSH remains disabled; key-only/non-root OpenSSH, existing grants and rollback remain. Test new public/LAN denial, authorized tailnet access and unauthorized-tailnet denial. Console recovery replaces a permanent LAN exception. Reboot/identity survival is a separately authorized check.

## Runtime secrets and persistence

Neither server has commissioned host recipients or selected secrets today. At the operator's explicit request, `secrets/web/operator.yaml` holds encrypted placeholders for private preparation under the existing operator recipient only; it is never a host input. Follow the [preparation instructions](../../../secrets/README.md#populate-the-preparation-files). First verify dedicated host age identities, independent recovery and early-mounted `/persist/var/lib/sops-nix/` key paths. Then add exact host creation rules containing only the existing operator and that verified host recipient, and privately split the required real values into those host files. Never add hosts to the combined preparation bundle, select placeholders for runtime use or put private age identities in the checkout.

Declare real SOPS files in the owning concern and select their names:

- Each proxy: `fleet.web.secrets.porkbunApiKey`, `porkbunSecretKey`, `httpBouncerKey`.
- Racknerd: `fleet.authentication.secrets.jwt`, `storage`, `users`, plus `smtpPassword` only in SMTP mode. Filesystem mode neither requires nor loads the SMTP password. `users` is the complete Authelia user-directory YAML, including privately generated password hashes, real groups and email addresses.

All selected source files must be root-owned `0400` under `/run/secrets`; systemd `LoadCredential` delivers private per-service files without environment substitution or CLI values. Add the corresponding service `restartUnits` on secret declarations; credential snapshots require a restart after rotation. Read every encrypted scalar, encrypted MAC and exact recipients before staging. Paths/declarations prove neither decryption nor LAPI registration.

Keep HTTP and firewall bouncer identities distinct. After separately authorized CrowdSec commissioning, in a private operator terminal on that host, redirect native `cscli bouncers add traefik-http --output raw` directly into a protected runtime file with umask 077; never display it or pass the key as an argument. Encrypt it to the correct host/operator recipients through private SOPS editing, then remove the private temporary copy after verified custody. Do not add it again if already registered: restore the matching key/database or perform an explicitly reviewed rotation. Native firewall registration stores its separate key at `/var/lib/crowdsec-firewall-bouncer-register/api-key.cred`, without printing it; its unit must finish before the bouncer starts.

Persistence is owned by each module:

- `/var/lib/traefik`, static `traefik:traefik`, `0700`: independent staging/production ACME stores and accounts per proxy. Never synchronize `acme.json` or certificate keys.
- `/var/lib/crowdsec` and `/var/lib/crowdsec-firewall-bouncer-register`, static `crowdsec:crowdsec`, `0700`: SQLite, hub/data and local identities. State-owning units explicitly disable DynamicUser to avoid `/var/lib/private` relocation. The firewall enforcement unit has runtime-only state and retains native DynamicUser.
- Racknerd `/var/lib/authelia-main`, static `authelia-main:authelia-main`, `0700`: SQLite MFA/storage data.

Before activating bindings, inspect existing state and effective unit ownership with authorized access; back up and seed the matching paths without overwriting identities. Restore SQLite consistently with its WAL and matching encryption keys. No `/run/secrets`, whole `/etc` or whole `/var` is persisted. Hub links under `/etc/crowdsec` are reconstructed by native setup from persisted hub data. Persistence is neither encryption nor backup.

## CrowdSec detection and limitations

Pinned server baseline: nixpkgs `c3eea5b2156db11c7eeeada3dc737711255b253e`, Traefik 3.7.13, Authelia 4.39.20, CrowdSec 1.7.8, firewall bouncer 0.0.34. Traefik bouncer v1.7.1 resolves to commit `bef5dfaadbb07381af02ec4e7391e49214ebf953`, NAR SHA-256 `hefOKDVsBxn+rCAylPHqbCNfPMbU/vtO4QpiftIPcUU=`. Its store source is mounted read-only into native `plugins-local`; no startup plugin download.

Hub revision `4c9fec5fe135c0b23d0059ae3e4ea9a6936e2f48` is the snapshot at the CrowdSec 1.7.8 release (2026-05-11). Native cscli uses the pinned raw GitHub URL template because the default CDN returns 404 for immutable commit paths. Hub item hashes are checked against that snapshot's index. Selected collection/dependency closure: SSH, Traefik/base HTTP/CVE, AppSec virtual patches/generic rules, plus explicit syslog/date/GeoIP parsers. Native 1.7.8 configuration validation loaded this closure and all 187 selected in-band AppSec rules. Review again when changing pins. No 1.8 bot challenge, `crowdsecurity/linux`, crawler whitelist, blanket private-network parser whitelist or CAPI/Console enrollment is selected. Audit existing persisted LAPI allowlists and old hub installations too: removing a declarative collection does not uninstall previously enabled items.

Acquisition is `sshd.service` UTC short-format journal records (`--output=short --utc`) with `type=syslog`, and `traefik.service` journal message-only JSON with `type=traefik`. The explicit systemd PATH lets native acquisition execute journalctl. Traefik keeps client address, method/path/protocol/status, timestamp, duration/router and User-Agent. Native `fields.queryParameters.defaultMode=drop` strips query tokens while retaining paths; all other headers are dropped, including Cookie/Authorization/Referer. The existing persistent journal remains bounded at 256M. Do not switch to an unbounded access-log file or debug/provider traces.

Racknerd's `assets/crowdsec/public-non-canada.yaml` triggers an IP ban on the first public HTTP event outside CA, including missing GeoIP, for four hours. Listed local/special transport ranges are excluded **only from this scenario**; SSH/HTTP abuse still applies to private clients. Bastion has no geography scenario. This is reactive: a non-Canadian request may reach login or an authorized backend before detection/polling. It is not first-request geofencing, citizenship verification or VPN prevention. HTTP stream startup synchronizes immediately, refreshes every 5s and uses `updateMaxFailure=0`; errors deny only after detection of the failure. AppSec errors/unreachability/unreadable bodies block. Actual startup/outage behavior remains a commissioning check.

Native nftables set-only enforcement uses separate IPv4/IPv6 sets and early input chains at priority -10, dropping only TCP 22/443. It does not drop forwarding, Tailscale outer UDP, DNS or NAS services. Bans can still affect a private management client's inner SSH connection; keep console recovery. Restarting nftables clears sets until the bouncer resynchronizes. The HTTP bouncer/AppSec/MFA remain separate controls, not proof of instantaneous firewall enforcement.

`assets/crowdsec/bots.yaml` adds one small in-band User-Agent rule for six reviewed signatures: GPTBot, ChatGPT-User, OAI-SearchBot, Googlebot, AhrefsBot and SemrushBot. Sources: [OpenAI](https://platform.openai.com/docs/bots), [Google](https://developers.google.com/search/docs/crawling-indexing/overview-google-crawlers), [Ahrefs](https://ahrefs.com/robot), [Semrush](https://www.semrush.com/bot/). This is deliberately not an exhaustive crawler inventory. Signatures can be spoofed; robots-only tokens are not HTTP identities. No blanket curl/empty-UA rejection. No-index/no-archive response headers are advisory. MFA is the meaningful private-content boundary; an authenticated scraper cannot reliably be distinguished from a person.

### GeoIP maintenance

GeoIP enrichment downloads local City/ASN databases from the URLs declared in the pinned `crowdsecurity/geoip-enrich` parser; no visitor-IP lookup API is used. Native `autoUpdateService` runs only `cscli hub update` and is deliberately disabled. After separately authorized maintenance, use `cscli parsers upgrade crowdsecurity/geoip-enrich --force`, then the separately authorized CrowdSec restart. At 1.7.8, `pkg/hubops/download.go` refreshes associated datasets; `--force` bypasses the seven-day shelf-life/last-modified shortcut. It does not move the pinned hub revision. Review the command's downloaded URLs/results, compare file hashes and source Last-Modified metadata, and check MMDB build metadata with a reviewed MMDB reader plus known controlled IP classifications. A recent local mtime or successful hub-index update is not proof of a current GeoIP database. Stop if refresh fails or observed build age/classification is unacceptable; do not bypass unknown-country bans. Back up existing data before replacement.

## Porkbun operator project

`opentofu/porkbun/main.tf` pins OpenTofu 1.12.6 and `jianyuan/porkbun` 0.3.2 with its own reviewed dependency lock. The registry supplied no GPG key, so native initialization reported skipped signature validation; the Linux amd64 archive SHA-256 was separately compared with the upstream v0.3.2 release checksum (`17a0d3e98cbe17a97e41b1f7090f4eb340ae1dc5756001395a61651505c8c224`). This is checksum agreement, not verified publisher-signature evidence. No fourth task, tailnet credentials, host input or automatic secret loader is involved. The nullable domain and empty typed record map currently instantiate **zero records**. Record definitions and verified existing IDs should be reviewed in the HCL defaults, not supplied through automatic variable overrides. Existing selected records use declarative imports with `<record_id>_<domain>_<type>` IDs; only genuinely new records omit `record_id`. No zone recreation, speculative AAAA/wildcards, Bastion LAN publication or ACME `_acme-challenge` ownership. `prevent_destroy` requires explicit configuration/review changes before any deliberate deletion/replacement. Preserve unrelated MX/TXT/CAA and split DNS. Public auth/apps eventually target the verified Racknerd address.

`secrets/porkbun/operator.yaml` now contains explicitly requested encrypted `REPLACE_ME` placeholders under its exact operator-only creation rule. Before any OpenTofu use, privately replace all three with real values: exactly `PORKBUN_API_KEY`, `PORKBUN_SECRET_KEY`, `TF_VAR_state_passphrase`, encrypted only to the existing operator. Keep this passphrase independently recoverable and separate from tailnet custody. Proxy Lego credentials instead use `PORKBUN_API_KEY_FILE` and `PORKBUN_SECRET_API_KEY_FILE`. Prefer separately revocable credentials per consumer if supported, but treat every proxy key as broad authority over API-enabled domains until actual restrictions are verified; do not claim record-level isolation.

Use only the default workspace and native local backend locking. Runtime root is `${XDG_STATE_HOME:-$HOME/.local/state}/infra/porkbun`, outside Git/store, with operator-owned 0700 directories, 0600 files, no symlinks/hard-linked files or group/other-writable ancestry. Inspect existing paths before creating missing directories with umask 077; never recursively repair permissions or replace state. Set `data/` as TF_DATA_DIR, `terraform.tfstate` as backend path, and keep unique encrypted plans under `plans/`. Preserve native encrypted backups too. Demonstrate independent recovery of the age key, passphrase and encrypted backend in separate private storage before apply. Do not rotate encryption IDs/passphrase or migrate the backend casually.

Before **every** native OpenTofu invocation:

1. Require a clean, reviewed committed revision, reviewed lockfile and the same privately recorded revision/hash for any saved plan. A clean tree is not human review. Do not commit without asking.
2. Inspect project entries, including hidden files, directories and dangling symlinks, for forbidden automatic variables. This command must print nothing; otherwise stop without reading secret content:

   ```sh
   find opentofu/porkbun -mindepth 1 -maxdepth 1 \( -name terraform.tfvars -o -name terraform.tfvars.json -o -name '*.auto.tfvars' -o -name '*.auto.tfvars.json' \) -print
   ```

3. Inspect environment **names only**, never values: `env | cut -d= -f1 | grep -E '^(TF_|TOFU_|PORKBUN_)'`. Remove unreviewed overrides, including CLI arguments/config, encryption config, workspaces, variable overrides, provider base URL and logging. No concurrent checkout/state edits. Check private paths/modes, default workspace and no local provider override configuration. The SOPS source must contain only the three reviewed keys above.
4. Run with `sops exec-env --pristine`, explicit absolute toolbox executable, `TF_CLI_CONFIG_FILE=/dev/null`, `TF_WORKSPACE=default` and the private TF_DATA_DIR. Never enable shell tracing, TF_LOG/provider traces, sensitive JSON, plaintext plans or credential-bearing arguments.

After explicit authorization for the relevant operation, set these **non-secret** paths in a private operator shell (paths used in the command strings must not contain single quotes):

```sh
set +x
umask 077
state="${XDG_STATE_HOME:-$HOME/.local/state}/infra/porkbun"
tofu=$(command -v tofu)
# Inspect/create private state/data/plans directories as above first.
sops exec-env --pristine secrets/porkbun/operator.yaml \
  "TF_DATA_DIR='$state/data' TF_CLI_CONFIG_FILE=/dev/null TF_WORKSPACE=default '$tofu' -chdir=opentofu/porkbun init -lockfile=readonly -input=false -backend-config=path='$state/terraform.tfstate'"
```

Choose a new, private absolute `$plan` filename beneath `$state/plans/`, then rerun the invocation preflight above. Plan and inspect in the same pristine authenticated environment:

```sh
sops exec-env --pristine secrets/porkbun/operator.yaml \
  "TF_DATA_DIR='$state/data' TF_CLI_CONFIG_FILE=/dev/null TF_WORKSPACE=default '$tofu' -chdir=opentofu/porkbun plan -input=false -lock-timeout=60s -out='$plan'"
sops exec-env --pristine secrets/porkbun/operator.yaml \
  "TF_DATA_DIR='$state/data' TF_CLI_CONFIG_FILE=/dev/null TF_WORKSPACE=default '$tofu' -chdir=opentofu/porkbun show '$plan'"
```

Privately record the clean revision and saved-plan SHA-256 and inspect the encryption envelopes without decrypting into logs. Native PBKDF2/AES-GCM state and plan encryption is enforced without plaintext fallback. Review imports and **only selected** DNS changes; investigate unrelated drift, replacement or deletion. Back up and demonstrate restore before asking to apply this exact plan.

After separate authorization for that exact reviewed plan, repeat preflight and verify its hash/revision, then:

```sh
sops exec-env --pristine secrets/porkbun/operator.yaml \
  "TF_DATA_DIR='$state/data' TF_CLI_CONFIG_FILE=/dev/null TF_WORKSPACE=default '$tofu' -chdir=opentofu/porkbun apply -input=false -lock-timeout=60s '$plan'"
```

Record every apply attempt privately and never reuse an attempted plan. Partial failure is not permission to retry: inspect state/live DNS, generate and review a new encrypted plan. Never disable locking, destroy a zone, automatically retry or repurpose `tailnet:deploy`.

## Certificates and commissioning acceptance

Independently authorize staging DNS-01 issuance on each proxy. Use the verified public resolvers and normal authoritative propagation checks despite split DNS; do not disable validation. Request only the actual authentication name initially. Check concurrent TXT creation/cleanup, renewal and rate limits, then separately authorize production with each proxy's own ACME store. No public port 80 is required.

After explicit operational authorization, verify:

- DNS inventory/import plan and unrelated records, encrypted state/credential restore, private SOPS decryption and state ownership without exposing values.
- Staging then production certificates/renewal on both proxies, public Racknerd versus home Bastion split DNS, direct central portal/ForwardAuth, Secure/HttpOnly cookie behavior and MFA. After a real app is added, default-denied requests never reach it and no backend bypass exists.
- Controlled CA/non-CA, IPv6, missing GeoIP, forged forwarding/identity headers, declared bot signatures and private-client SSH abuse; confirm finite ban delay and both HTTP/firewall enforcement without harming Tailscale UDP.
- Separately authorized CrowdSec/AppSec and central-auth/link failures deny protected requests; prove actual journal consumption and startup behavior, not just active units.
- Private admin/deploy access, unauthorized-tailnet denial and console/rollback before SSH cutover; public/LAN denial and retained tailnet SSH after each host's separately authorized cutover; identity survival only after separately authorized reboot.

## Local verification and current limitations

Run the approved local commands: `nix fmt`, `git diff --check`, `nix flake check --no-update-lock-file -L`, each server's `nix eval --no-update-lock-file --json .#fleet.HOST` and `nix build --no-update-lock-file --no-link .#nixosConfigurations.HOST.config.system.build.toplevel`, and `tofu -chdir=opentofu/porkbun fmt -check`. Use a private disposable TF_DATA_DIR outside the checkout for credential-free `init -backend=false -lockfile=readonly -input=false` then `validate`, with no operational backend/decryption. Inspect generated gate-off settings and missing-fact assertions, middleware order, secret paths/listeners, parser fields, nftables priorities and unchanged tailnet/deploy/ThinkPad/NAS/disk declarations.

### Filesystem notifier verification

Authelia 4.39.20's `internal/notification/file_notifier.go` and `const.go` establish overwrite/startup-clearing behavior and `0600` file creation. The native NixOS unit uses the static `authelia-main` account and `ProtectSystem=strict`; systemd's private RuntimeDirectory supplies the writable location. This credential-free check evaluates both notifier branches without starting services or satisfying commissioning assertions:

```sh
nix eval --no-update-lock-file --impure --expr '
let
  host = (builtins.getFlake (toString ./.)).nixosConfigurations.racknerd;
  lib = host.pkgs.lib;
  configFor = extra: (host.extendModules {
    modules = [ { fleet.web.enable = true; } extra ];
  }).config;
  fs = configFor {};
  smtp = configFor { fleet.authentication.notifier = "smtp"; };
  notifier = c: c.services.authelia.instances.main.settings.notifier;
  unit = fs.systemd.services.authelia-main;
  blocked = prefix: c: builtins.any (a: !a.assertion && lib.hasPrefix prefix a.message) c.assertions;
in
assert !host.config.fleet.web.enable;
assert notifier fs == { disable_startup_check = false; filesystem.filename = "/run/authelia-main/notifications.txt"; };
assert unit.serviceConfig.RuntimeDirectory == "authelia-main" && unit.serviceConfig.RuntimeDirectoryMode == "0700" && unit.serviceConfig.UMask == "0077";
assert !(unit.environment ? AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE);
assert !(builtins.any (lib.hasPrefix "smtpPassword:") unit.serviceConfig.LoadCredential);
assert (notifier smtp) ? smtp && !((notifier smtp) ? filesystem) && !(notifier smtp).disable_startup_check;
assert smtp.systemd.services.authelia-main.environment ? AUTHELIA_NOTIFIER_SMTP_PASSWORD_FILE;
assert builtins.any (lib.hasPrefix "smtpPassword:") smtp.systemd.services.authelia-main.serviceConfig.LoadCredential;
assert !(blocked "Authelia SMTP mode" fs) && blocked "Authelia SMTP mode" smtp;
assert blocked "Authelia requires declared" fs && blocked "Authelia requires declared" smtp;
true
'
```

The missing-secret assertions must still fail in both branches: no fabricated secret declarations are used. After real secret commissioning, replace that negative expectation with checks against the reviewed selections. Actual file ownership, writes and manual MFA enrollment remain unperformed until separately authorized activation.

### Native replay result — 2026-09-15

**Passed after two fixes.** The initially credential-free `-no-api` attempt failed before processing: CrowdSec 1.7.8 still authenticates a watcher. The user subsequently authorized an isolated disposable native LAPI and temporary test credentials. No real secrets, hosts, production LAPI/state or enforcement were involved.

The test used the selected pinned hub closure, byte-identical local scenario/assets and downloaded public GeoIP databases under `/tmp/infra-proxy.zh5ifk/replay`. `test-config.yaml` redirected every mutable path there, used SQLite `data/test-replay.db`, bound LAPI exclusively to `127.0.0.1:59189`, disabled CAPI/Console sharing and metrics, and selected the actual four-hour local remediation profile. File replay replaced acquisition only; it did not read the machine's journal or start AppSec/bouncers. These addresses were synthetic log inputs, never network targets or fleet facts.

Exact successful native invocations (private umask 077, with all output redirected into the disposable directory):

```sh
w=/tmp/infra-proxy.zh5ifk/replay
bin=/nix/store/kf7z9lh7dsfabg8pvqfbraf2pixxkvzy-crowdsec-1.7.8/bin
"$bin/cscli" -c "$w/test-config.yaml" machines add replay --auto \
  --file "$w/test-client.yaml" > "$w/test-register.log" 2>&1
"$bin/crowdsec" -c "$w/test-config.yaml" -no-capi \
  -dsn "file://$w/test-http-final.log" -type traefik \
  -dump-data "$w/test-http-final-dump" -order-event > "$w/test-http-final-result.log" 2>&1
"$bin/crowdsec" -c "$w/test-config.yaml" -no-capi \
  -dsn "file://$w/test-ssh-final.log" -type syslog \
  -dump-data "$w/test-ssh-final-dump" -order-event > "$w/test-ssh-final-result.log" 2>&1
python3 "$w/check.py"
```

The temporary assertion script consumed the native YAML dumps via toolbox `yq -o=json`, not a reimplementation of parsing or policy. It required all 9 HTTP inputs to parse with their original `ClientHost` and timestamps despite an extra forged `request_X-Forwarded-For: 1.1.1.1` field. The exact overflow set was:

| Synthetic HTTP source | Native GeoIP | Geography overflow |
|---|---|---|
| `24.48.0.1` | CA | none |
| `8.8.8.8`, `2001:4860:4860::8888`, `::ffff:8.8.4.4` | US | one per source, on its first event |
| `3000::1` | empty/unknown | one on its first event |
| `192.168.2.10`, `100.64.0.10`, `fd7a:115c:a1e0::10`, `::ffff:192.168.2.12` | private transport | none |

All four geography overflows had `remediation=true`. All 16 UTC short-format SSH logs parsed: eight failed-publickey records for synthetic existing user `replay-user` from `192.168.2.10`, and eight `Invalid user denied` records from `100.64.0.20`, each at one-second intervals. Native `crowdsecurity/ssh-bf` overflowed for each private source at six events over **5s**, with `remediation=true`, and no geography overflow. The dump also contained the two expected native reprocessed overflow events. The check printed:

```text
PASS: 9 HTTP events, 4 single-event country overflows; 16 SSH events, 2 private-source SSH overflows; source IPs and timestamps preserved.
```

The replay exposed and fixed two concrete errors:

- Removed `::ffff:0:0/96` from the geography exclusions: native `IpInRange` uses Go `net.IPNet.Contains`, which also matches ordinary IPv4 against that range. It had incorrectly excluded **all IPv4**. Mapped private addresses still match the specific private IPv4 ranges; mapped public addresses now trigger normally.
- Changed SSH acquisition from short-ISO to short UTC output: the pinned date parser did not accept the `+0000` short-ISO timestamp and silently substituted current time. The corrected replay preserves the actual timestamps instead of compressing eight seconds of logs into milliseconds.

A preliminary standalone `Failed publickey for invalid user ...` record was not recognized by the pinned SSH parser. The final test covers recognized existing-user key failures and the accompanying native `Invalid user` event, not every possible OpenSSH message. Real `sshd.service` journal consumption remains a commissioning check. Likewise, ignoring an injected field in a synthetic log does **not** prove Traefik strips an actual visitor's forged forwarding headers; that live boundary remains unperformed.

GeoIP SHA-256 at replay: City `eefe3ce149ce98be5e28b14bb0557ab30faca97720b36b820218c0e402d13e6a`, ASN `6eba4c0e06655456fc121332b663108297901b2fca99a5aa1bec2043ed27f605`. Both replay processes exited successfully; the temporary listener stopped and generated test credentials/database were removed afterward. These are disposable paths, not a reusable commissioned identity. Repeating the test requires a newly authorized isolated setup, never redirecting it to production.

Native config-only validation **passed** with the same closure/assets and temporary AppSec acquisition:

```sh
/nix/store/kf7z9lh7dsfabg8pvqfbraf2pixxkvzy-crowdsec-1.7.8/bin/crowdsec \
  -c /tmp/infra-proxy.zh5ifk/replay/config.yaml -no-api -t
```

It reported `Loaded 187 inband rules` and `Configuration test done`; no listener was started. This is syntax/compatibility evidence, not parsing/replay or enforcement. Flake check evaluates outputs only, and gate-off builds prove no runtime readiness. Temporary validation paths are disposable, not operational state. All commissioning acceptance above is unperformed until separately authorized and reported.

Upstream boundaries: [pinned NixOS services](https://github.com/NixOS/nixpkgs/tree/c3eea5b2156db11c7eeeada3dc737711255b253e/nixos/modules/services), [Authelia integration](https://www.authelia.com/integration/proxies/traefik/), [bouncer v1.7.1](https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/tree/v1.7.1), [Porkbun provider](https://github.com/jianyuan/terraform-provider-porkbun/tree/v0.3.2/docs), [Lego Porkbun](https://go-acme.github.io/lego/dns/porkbun/), [OpenTofu encryption](https://opentofu.org/docs/language/state/encryption/).
