# OpenCloud

[opencloud.nix](../../../modules/opencloud.nix) runs the production line of OpenCloud (files
only) and publishes `cloud.` through both proxies ([proxy skill](../proxy/SKILL.md)). Its
proxy speaks plain HTTP behind Caddy and its built-in identity provider is off: everyone signs in
through Authelia ([identity](identity.md)). A
first sign-in creates the account; the role comes from the person's Authelia groups
(`opencloudAdmin`, `opencloudUser`), and someone with no such group cannot sign in. App tokens
are on (the `auth-app` service and the proxy's app auth), for the calendar and contacts clients,
which cannot do OpenID Connect ([calendar](calendar.md)). A token signs in
without Authelia's second factor, reaches the files as well as the calendar, and outlives a
lockout or a disabled account in Authelia; the operator accepted that for per-device tokens
each person can revoke. Removing a person from Authelia leaves their tokens working: delete
them in OpenCloud too.

Everything lives on `tank/opencloud` at `/srv/opencloud`, and both units refuse to start without
that mount. That includes `config/opencloud.yaml`, which the first start generates and which
holds the inter-service secrets and ids: it is not in Git or sops, so losing the dataset loses
the installation, and copying it is how a restore works. A production release is upgraded only
forward; moving to the rolling line and back is a downgrade OpenCloud does not support.

Sign-in
and the folder pairs are set in the desktop client, whose token lives in the system keychain, so they are
not declared. The desktop and mobile clients take Authelia's `sync` lifespan
([identity](identity.md)), so a machine that sleeps past Authelia's default refresh
window stays signed in; the price is a lost device that keeps file access, without a second
factor, until that token expires. The web app keeps the default. On Linux it starts with the Fusion style, because Stylix's Kvantum has no QML
style and the client aborts under it.
