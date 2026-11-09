---
name: monitoring
description: "Monitoring on bastion: Prometheus and the exporters it scrapes, Loki and the Alloy journal shipper, Grafana at grafana.DOMAIN with its Authelia sign-in, datasources and dashboards, the alert rules and where they go (ntfy, email, the healthchecks.io heartbeat), and ntfy at ntfy.DOMAIN. Use before touching modules/monitoring.nix or modules/ntfy.nix, adding a scrape target, exporter, dashboard or alert, subscribing a device, or debugging missing metrics, logs, alerts or Grafana sign-in."
---

# Monitoring

[monitoring.nix](../../../modules/monitoring.nix) runs the stack on bastion, every port on loopback.
Prometheus, Loki and the node exporter answer without authentication, so an nftables guard admits
only root and the stack's own users (pinned uids) to their ports; otherwise any service on bastion
could read the whole journal through Loki.
Prometheus scrapes its own exporters (node with the systemd collector, itself) every 60 s and keeps
30 days, capped at 20 GB. Alloy ships bastion's journal to Loki with `host`, `unit`,
`syslog_identifier` and `level` labels, dropping lines older than 12 h; Loki keeps 30 days.
Their data lives under `/persist` and stays out of the backups ([backups skill](../backups/SKILL.md)):
losing it costs history, nothing else. Alloy keeps no journal position across reboots, so
the last 12 h may be shipped twice after one.

Grafana sits behind the LAN proxy at `grafana.`, tailnet only ([proxy skill](../proxy/SKILL.md)).
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
ships the journal. It pushes to the port pair in its
`fleet.hosts.HOST.telemetry`; bastion's Alloy listens on that pair, stamps `host=HOST` and forwards
into the local Prometheus and Loki, and its firewall admits the pair only from that host's tailnet
address, with a tailnet grant for the same ports ([opentofu skill](../opentofu/SKILL.md)). Nothing
is authenticated, an accepted risk: a compromised host can push false data under its own name but
read nothing. Each sender gets a `Host silent HOST` alert when its metrics stop.

## Alerts

Grafana evaluates the rules in the `Fleet` folder every minute; each is one `rule` entry in the
module (PromQL whose value is compared with its `threshold`, default `for` 15 m, no data counts as
fine). Everything goes to ntfy's `alerts` topic; `severity=critical` also goes to ntfy at high
priority and to the email of every `grafana-admins` person, through Authelia's SMTP account. The
always-firing `Heartbeat` goes only to the healthchecks.io URL in `grafana/heartbeat-url` about
every 5 minutes (repeat 4 m on a 1 m tick, since a repeat equal to the tick fires every other
tick), so the outside check, period 5 m and grace 10 m, alerts when bastion, Grafana or the
network stops. Provisioning
never deletes a rule: a retitled or removed rule's uid goes in `deleteRules` for one deploy.

[ntfy.nix](../../../modules/ntfy.nix) serves `ntfy.` through the LAN proxy to the LAN and the
tailnet. Everything is denied by default; `alerts` and `media` are readable by anyone who reaches
it, and only the `publisher` user (its token in `ntfy/publisher-token`) may publish. Subscribe on
a phone or desktop to `https://ntfy.DOMAIN/alerts` with no login.

```sh
ssh bastion "systemctl status prometheus loki alloy grafana"
ssh -t bastion "sudo curl -s 127.0.0.1:9090/api/v1/targets" | jq '.data.activeTargets[] | {job: .labels.job, health}'
ssh -t bastion "sudo curl -s 127.0.0.1:3100/ready"
```
