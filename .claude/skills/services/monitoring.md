# Monitoring

[monitoring.nix](../../../modules/monitoring.nix) runs the stack on bastion, every port on loopback except the ones Alloy takes other hosts' telemetry and the gateway's syslog on.
Each exporter sits beside what it measures (SMART here, the UPS in the bastion host's `ups.nix`,
the arr apps' health in `arr.nix`)
and adds its port to `fleet.scrapeTargets`, which becomes a Prometheus job. Prometheus, Loki and
every scrape target answer without authentication, so an nftables guard admits only root and the
stack's own users (pinned uids) to Loki's ports, every `fleet.scrapeTargets` port and the ports Alloy receives other hosts' telemetry
on, and refuses the gateway's syslog port to every local sender; otherwise
any service on bastion could read the whole journal through Loki or push data under another host's name. Exporter ports sit at 19xxx,
clear of OpenCloud's internal block from 9100; CrowdSec's own metrics listener keeps 6060.
Alloy ships bastion's journal to Loki and drops lines older than 12 h.
Their data lives under `/persist` and stays out of the backups ([backups skill](../backups/SKILL.md)):
losing it costs history, nothing else. Alloy keeps no journal position across reboots, so
the last 12 h may be shipped twice after one. On a host with a `fleet.hosts.HOST.lan` fact, Alloy
also takes the UniFi gateway's syslog (firewall blocks, IPS detections, admin activity) over UDP
from the gateway alone and stores the lines unparsed under `host="gateway"`
([opentofu skill](../opentofu/SKILL.md)).

Grafana sits behind the LAN proxy at `grafana.`, on the LAN and the tailnet ([proxy skill](../proxy/SKILL.md)).
People sign in through Authelia; membership of `grafana-admins` makes them Grafana admins and
everyone else is refused ([identity](identity.md)). The local `admin` with
`grafana/admin-password` is the break-glass login. Grafana reads that secret only when it creates
its database, so rotating it also means setting the new value on the `admin` user under
Administration → Users while signed in through Authelia; changing the secret alone restarts
Grafana and changes nothing. Datasources (`prometheus`, `loki`) and
dashboards are provisioned read-only: change them in Nix, not in the UI. Dashboards are pinned
community ones by grafana.com revision and hash, with their datasource input replaced by the
provisioned uid; a bump is a new revision and hash. One query is corrected on the way in: the UPS
dashboard's wattage panel divided nominal power by the load percentage, and now multiplies. That
figure is the draw of everything on the UPS, not of bastion alone; the workstations send no
telemetry, so nothing shows theirs.

## Other hosts

A host that imports `telemetry` runs Alloy, which scrapes its node metrics and every
`fleet.scrapeTargets` endpoint, probes every `fleet.probes` URL (the
public hostnames, which the edge resolves to loopback so its own probes skip the country
rule and CrowdSec; they test the passthrough, the tunnel, bastion's public listener and the apps, not reachability from outside), and
ships the journal. Caddy serves its metrics on a loopback port of their own; its admin API on 2019,
which can rewrite its config and expose the Porkbun keys it holds, admits only root and Caddy on
every host ([caddy.nix](../../../modules/caddy.nix)). It pushes to the port pair in its
`fleet.hosts.HOST.telemetry`; bastion's Alloy listens on that pair, stamps `host=HOST` and forwards
into the local Prometheus and Loki, and its firewall admits the pair only from that host's tailnet
address, with a tailnet grant for the same ports ([opentofu skill](../opentofu/SKILL.md)). Nothing
is authenticated, an accepted risk: a compromised host can push false data under its own name but
read nothing. Each sender gets a critical `Host silent HOST` alert once its metrics have stopped for 10 minutes,
since its own alerts, the edge's probes among them, stop with it and no data counts as fine.
A Linux workstation imports `logs` instead, the journal half of `telemetry`, with `metrics = null`
in its `telemetry` fact: no metrics and no `Host silent` alert, since a laptop that is shut, asleep
or off the tailnet is normal. Every sender retries its log pushes forever, so while bastion is out
of reach Alloy's queue fills and then stops reading the journal, which holds the backlog until the
tailnet returns; Loki refuses pushed lines over a week old (its default ingestion window, apart
from how long it keeps what it stored). A sender's Alloy state is under `/persist`, so it resumes
from its journal position after a reboot instead of shipping the last 12 h again, but still skips
lines older than 12 h, so a laptop rebooted after more than 12 h away loses the lines it never
sent. Each metrics sender also gets a `Logs silent HOST` alert once Loki has taken nothing from it
for 45 minutes, which catches a push that retries forever on a batch Loki keeps refusing.
Bastion's own Alloy probes `https://auth.DOMAIN` through the gateway's wildcard record, so the
LAN proxy's certificate and reachability get the same `Public endpoint down` and `Certificate
expiring` alerts as the edge's. It also probes `auth.DOMAIN` at each `fleet.hosts.HOST.publicAddress`
from outside, since the edge's own probes skip its firewall, the country check and CrowdSec; neither probe
resolves the public record, and a home WAN outage fires this one too. The `alloy-HOST`
check runs `alloy fmt` on every host's Alloy configuration, which catches syntax errors (a missing
trailing comma in a multi-line list) but not unknown arguments or wrong component wiring.

## Alerts

Grafana evaluates the rules in the `Fleet` folder every minute; each is one `rule` entry in the
module (PromQL, or a LogQL metric query with `datasource = "loki"`, whose value is compared with
its `threshold`, default `for` 15 m, no data counts as fine). The gateway's syslog has no sample
of an IPS or honeypot event yet, so `Gateway security event` fires on any `UNIFIcategory=Security`
line except a plain firewall block. Everything goes to ntfy's `alerts` topic; `severity=critical` also goes to ntfy at high
priority and to the email of every `grafana-admins` person, through Authelia's SMTP account. The
always-firing `Heartbeat` goes only to the healthchecks.io URL in `grafana/heartbeat-url` about
every 5 minutes (repeat 4 m on a 1 m tick, since a repeat equal to the tick fires every other
tick), so the outside check, period 5 m and grace 10 m, alerts when bastion, Grafana or the
network stops. A job that records its own result writes a `*.prom` file to `fleet.metricsDir`
(persisted), which the node exporter publishes: each restic backup and the restore drill write
`restic_last_success_timestamp_seconds{backup=…}` only after succeeding, because a run that never
starts (its USB disk missing) leaves the unit inactive rather than failed and the timer fresh. `restic-success-seed` writes
the current time for a job with no file yet, so one that never succeeds still goes stale, and
deletes the files of removed jobs.
Provisioning never deletes a rule: a retitled or removed rule's uid goes in `deleteRules` for one deploy.

Three rules watch for compromise, not failure. `Server login` fires on every SSH login to a server
except the build account's and a `deploy` login from a workstation's tailnet address, so a deploy
is quiet and any other login stands out; a stolen laptop's deploy key therefore logs in unseen.
`Unexpected certificate` is critical: the proxy's `certificate-watch` job found a certificate for the
domain in the public logs whose key the proxy does not hold ([proxy skill](../proxy/SKILL.md)).
`Authelia mail failing` catches a broken SMTP account, which Authelia no longer tests at start
([identity](identity.md)). `ZFS data errors` is critical: ZED logs a checksum, I/O
or data error, which a scrub or a read can find while the pool stays online and `zpool scrub`
still exits cleanly. A checksum or I/O error on one disk of a redundant pool is repaired from
another copy and points at a failing disk; a `data` error is a block lost for good: reading the
file fails, so the nightly backup leaves it out and fails (`Unit failed`), and its last good copy
ages out of retention unless it is restored first. The alert clears ten minutes after the last
event while the damage stays, so its one notification is the signal.

[ntfy.nix](../../../modules/ntfy.nix) serves `ntfy.` through the LAN proxy to the LAN and the tailnet;
the `alerts` topic needs no login and describes the fleet, an accepted exposure to every client the LAN proxy admits (Home, Kids, the IoT players), to the agents guest ([guests: agents](../guests/agents.md)) and to bastion's own processes through the proxy. Everything is denied by default; `alerts` is readable by anyone who reaches
it, and only the `publisher` user (its token in `ntfy/publisher-token`) may publish. Subscribe on
a phone or desktop to `https://ntfy.DOMAIN/alerts` with no login. Each workstation subscribes
itself: `ntfy-alerts`, a Home Manager user service, shows each alert
as a notification, critical from priority 4 on Linux, and only while the tailnet is up, so alerts
sent while the laptop was off or away reach only the phone.

Bastion admits no login ([operating: deploy](../operating/deploy.md)), so debug the stack through Grafana's
Explore or the Grafana MCP tools: `up` in Prometheus lists every scrape target and its health,
`node_systemd_unit_state{instance="bastion",name=~"(prometheus|loki|alloy|grafana).service",state="active"}`
the stack's units, and `{host="bastion",unit="alloy.service"}` in Loki answers only while Loki is ready.
