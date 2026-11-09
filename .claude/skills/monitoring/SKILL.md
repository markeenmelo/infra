---
name: monitoring
description: "Monitoring on bastion: Prometheus and the exporters it scrapes, Loki and the Alloy journal shipper, Grafana at grafana.DOMAIN with its Authelia sign-in, datasources and dashboards. Use before touching modules/monitoring.nix, adding a scrape target, exporter or dashboard, or debugging missing metrics, logs or Grafana sign-in."
---

# Monitoring

[monitoring.nix](../../../modules/monitoring.nix) runs the stack on bastion, every port on loopback.
Prometheus scrapes its own exporters (node with the systemd collector, itself) every 60 s and keeps
30 days, capped at 20 GB. Alloy ships bastion's journal to Loki with `host`, `unit`,
`syslog_identifier` and `level` labels, dropping lines older than 12 h; Loki keeps 30 days.
Their data lives under `/persist` and stays out of the backups ([backups skill](../backups/SKILL.md)):
losing it costs history, nothing else. Alloy keeps no journal position across reboots, so
the last 12 h may be shipped twice after one.

Grafana sits behind the LAN proxy at `grafana.`, tailnet only ([proxy skill](../proxy/SKILL.md)).
People sign in through Authelia; membership of `grafana-admins` makes them Grafana admins and
everyone else is refused ([identity skill](../identity/SKILL.md)). The local `admin` with
`grafana/admin-password` is the break-glass login. Datasources (`prometheus`, `loki`) and
dashboards are provisioned read-only: change them in Nix, not in the UI. Dashboards are pinned
community ones by grafana.com revision and hash, with their datasource input replaced by the
provisioned uid; a bump is a new revision and hash.

```sh
ssh bastion "systemctl status prometheus loki alloy grafana"
ssh bastion "curl -s 127.0.0.1:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health}'"
ssh bastion "curl -s 127.0.0.1:3100/ready"
```
