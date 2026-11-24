# Immich

[immich.nix](../../../modules/immich.nix) serves the library at `photos.` through both proxies
([proxy skill](../proxy/SKILL.md)); the public listener denies its admin API, so administration happens on
the LAN or the tailnet. Sign-in is only through Authelia ([identity](identity.md)):
password login and first-admin setup are off, and `autoRegister` is off, so a person signs in
only once an Immich admin has created their user with the same email. The `immich-HOST` check parses
the settings with Immich's own schema and fails if setup is still offered.

Originals, thumbnails and encoded video live on `tank/immich` at `/srv/immich/library`, and the
server refuses to start without that mount; the `immich` uid and gid are pinned to the ids that
own the dataset, since a reinstall would otherwise allocate new ones. The database is `immich` in the shared PostgreSQL, with the VectorChord extension
the upstream module adds to the cluster, so the PostgreSQL dumps and a restore cover it.
