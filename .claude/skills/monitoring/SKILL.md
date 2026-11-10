---
name: monitoring
description: "Monitoring on bastion: Prometheus and the exporters it scrapes, Loki and the Alloy journal shipper, Grafana at grafana.DOMAIN with its Authelia sign-in, datasources and dashboards, the alert rules and where they go (ntfy, email, the healthchecks.io heartbeat), and ntfy at ntfy.DOMAIN. Use before touching modules/monitoring.nix or modules/ntfy.nix, adding a scrape target, exporter, dashboard or alert, subscribing a device, or debugging missing metrics, logs, alerts or Grafana sign-in."
---

# Monitoring

[monitoring.nix](../../../modules/monitoring.nix) runs the stack on bastion, every port on loopback.
Each exporter sits beside what it measures (SMART here, the UPS in the bastion host's `ups.nix`,
the arr apps' health in `arr.nix`)
and adds its port to `fleet.scrapeTargets`, which becomes a Prometheus job. Prometheus, Loki and
every scrape target answer without authentication, so an nftables guard admits only root and the
stack's own users (pinned uids), plus Caddy's for its own admin endpoint (2019, which serves
Caddy's metrics and its reloads), to Loki's ports, every `fleet.scrapeTargets` port and the ports Alloy receives other hosts' telemetry
on, and refuses the gateway's syslog port to every local sender; otherwise
any service on bastion could read the whole journal through Loki or push data under another host's name. Exporter ports sit at 19xxx,
clear of OpenCloud's internal block from 9100.
Prometheus scrapes its own exporters (node with the systemd collector, itself) every 60 s and keeps
30 days, capped at 20 GB. Alloy ships bastion's journal to Loki with `host`, `unit`,
`syslog_identifier` and `level` labels, dropping lines older than 12 h; Loki keeps 30 days.
Their data lives under `/persist` and stays out of the backups ([backups skill](../backups/SKILL.md)):
losing it costs history, nothing else. Alloy keeps no journal position across reboots, so
the last 12 h may be shipped twice after one. On a host with a `fleet.hosts.HOST.lan` fact, Alloy
also takes the UniFi gateway's syslog (firewall blocks, IPS detections, admin activity) over UDP
from the gateway alone and stores the lines unparsed under `host="gateway"`
([opentofu skill](../opentofu/SKILL.md)).

Grafana sits behind the LAN proxy at `grafana.`, on the LAN and the tailnet ([proxy skill](../proxy/SKILL.md)).
People sign in through Authelia; membership of `grafana-admins` makes them Grafana admins and
everyone else is refused ([identity skill](../identity/SKILL.md)). The local `admin` with
`grafana/admin-password` is the break-glass login. Grafana reads that secret only when it creates
its database, so rotating it also means setting the new value on the `admin` user under
Administration → Users while signed in through Authelia; changing the secret alone restarts
Grafana and changes nothing. Datasources (`prometheus`, `loki`) and
dashboards are provisioned read-only: change them in Nix, not in the UI. Dashboards are pinned
community ones by grafana.com revision and hash, with their datasource input replaced by the
provisioned uid; a bump is a new revision and hash.

## Other hosts

A host that imports `telemetry` runs Alloy, which scrapes its node metrics and every
`fleet.scrapeTargets` endpoint (CrowdSec on racknerd), probes every `fleet.probes` URL (the
edge's public hostnames, which racknerd resolves to loopback so its own probes skip the country
rule and CrowdSec; they test Caddy, the tunnel and the apps, not reachability from outside), and
ships the journal. As on bastion, an nftables guard lets only root and Alloy (pinned to bastion's
uid) connect to its scrape targets, plus Caddy to its own admin API on 2019, which also holds the
Porkbun keys. It pushes to the port pair in its
`fleet.hosts.HOST.telemetry`; bastion's Alloy listens on that pair, stamps `host=HOST` and forwards
into the local Prometheus and Loki, and its firewall admits the pair only from that host's tailnet
address, with a tailnet grant for the same ports ([opentofu skill](../opentofu/SKILL.md)). Nothing
is authenticated, an accepted risk: a compromised host can push false data under its own name but
read nothing. Each sender gets a critical `Host silent HOST` alert once its metrics have stopped for 10 minutes,
since its own alerts, the edge's probes among them, stop with it and no data counts as fine.
Bastion's own Alloy probes `https://auth.DOMAIN` through the gateway's wildcard record, so the
LAN proxy's certificate and reachability get the same `Public endpoint down` and `Certificate
expiring` alerts as the edge's. The `alloy-HOST`
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

[ntfy.nix](../../../modules/ntfy.nix) serves `ntfy.` through the LAN proxy to the tailnet only,
since the `alerts` topic needs no login and describes the fleet. Everything is denied by default; `alerts` and `media` are readable by anyone who reaches
it, and only the `publisher` user (its token in `ntfy/publisher-token`) may publish. Subscribe on
a phone or desktop to `https://ntfy.DOMAIN/alerts` with no login. Each workstation subscribes
itself: `ntfy-alerts`, a Home Manager user service (a launchd agent on the mac), shows each alert
as a notification, critical from priority 4 on Linux, and only while the tailnet is up, so alerts
sent while the laptop was off or away reach only the phone.

```sh
ssh bastion "systemctl status prometheus loki alloy grafana"
ssh -t bastion "sudo curl -s 127.0.0.1:9090/api/v1/targets" | jq '.data.activeTargets[] | {job: .labels.job, health}'
ssh -t bastion "sudo curl -s 127.0.0.1:3100/ready"
```
