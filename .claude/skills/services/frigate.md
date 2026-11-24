# Frigate

[frigate.nix](../../../modules/frigate.nix) serves the NVR at `frigate.` through the LAN proxy
only ([proxy skill](../proxy/SKILL.md)); it is not public, and Frigate's own login guards it.
The empty `appendConfig` drops the RTMP listener the upstream nginx config adds. The loopback ports behind
that login (nginx's unauthenticated 5000, Frigate's API, go2rtc's API and RTSP) refuse every local
user except `frigate` and `nginx`, by an nftables output rule, so another service on bastion
cannot reach the cameras or Frigate's admin API. MQTT is off: nothing
consumes Frigate's events.

The Tapo C120 sits on the Cameras VLAN, which bastion may reach on RTSP and ONVIF and which has
no internet. go2rtc pulls its main and sub streams once and restreams them on loopback; Frigate
records the main stream and detects on the sub stream.

No object filter is set; the knobs for false positives are person object
filters (`min_area`, `min_ratio`/`max_ratio`, `threshold`) and zone `inertia`. Recordings,
snapshots and the database live on `scratch/frigate` at `/var/lib/frigate`, rebuildable and not
snapshotted; Frigate refuses to start without that mount.
