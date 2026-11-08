---
name: frigate
description: "Frigate on bastion: the NVR at frigate.DOMAIN, the Tapo camera and its RTSP secrets, go2rtc restreaming, OpenVINO detection on the iGPU, false-positive filters, recordings on scratch/frigate. Use before touching modules/frigate.nix, adding a camera, tuning detection, or debugging streams or recordings."
---

# Frigate

[frigate.nix](../../../modules/frigate.nix) serves the NVR at `frigate.` through the LAN proxy
only ([proxy skill](../proxy/SKILL.md)); it is not public, and Frigate's own login guards it.
Its nginx listens on loopback alone, with the RTMP listener dropped. The loopback ports behind
that login (nginx's unauthenticated 5000, Frigate's API, go2rtc's API and RTSP) refuse every local
user except `frigate` and `nginx`, by an nftables output rule, so another service on bastion
cannot reach the cameras or Frigate's admin API. MQTT is off: nothing
consumes Frigate's events.

The Tapo C120 sits on the Cameras VLAN, which bastion may reach on RTSP and ONVIF and which has
no internet. go2rtc pulls its main and sub streams once and restreams them on loopback; Frigate
records the main stream and detects on the sub stream. The stream URLs, with the camera's
credentials, are `frigate-main` and `frigate-sub` in `secrets/hosts/bastion.yaml`, handed to
both services through `LoadCredential`.

Detection runs OpenVINO on the iGPU with the bundled SSDLite MobileNet model, tracking only
people, and alerts only inside `person_area`. False positives are tuned with person object
filters (`min_area`, `min_ratio`/`max_ratio`, `threshold`) and zone `inertia`. Recordings,
snapshots and the database live on `scratch/frigate` at `/var/lib/frigate`, rebuildable and not
snapshotted; Frigate refuses to start without that mount.
