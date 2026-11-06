---
name: immich
description: "Immich on bastion: the photo library at photos.DOMAIN, its Authelia sign-in, the media dataset, GPU transcoding and machine learning, its database, Redis and model cache. Use before touching modules/immich.nix, the render device, or debugging photo uploads, sign-in or transcoding."
---

# Immich

[immich.nix](../../../modules/immich.nix) serves the library at `photos.` through both proxies
([proxy skill](../proxy/SKILL.md)); the edge denies its admin API, so administration happens on
the LAN or the tailnet. Sign-in is only through Authelia ([identity skill](../identity/SKILL.md)):
password login and first-admin setup are off, and `autoRegister` is off, so a person signs in
only once an Immich admin has created their user with the same email. The mobile app's
`app.immich:///oauth-callback` is one of the client's redirects. The `immich-HOST` check parses
the settings with Immich's own schema and fails if setup is still offered.

Originals, thumbnails and encoded video live on `tank/immich` at `/srv/immich/library`, and the
server refuses to start without that mount; the `immich` uid and gid are pinned to the ids that
own the dataset, since a reinstall would otherwise allocate new ones. The database is `immich` in the shared PostgreSQL
with VectorChord, which the upstream module adds to the cluster. Redis and the
machine-learning model cache persist under `/persist`. Transcoding uses Quick Sync on the iGPU
named by `fleet.renderDevice` ([hardware.nix](../../../modules/hosts/bastion/hardware.nix)).
