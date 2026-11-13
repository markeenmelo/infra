---
name: opencloud
description: "OpenCloud on bastion: file sync at cloud.DOMAIN, its Authelia sign-in and roles, the desktop and mobile clients, the dataset and the generated config that holds its secrets. Use before touching modules/opencloud.nix, adding a person to OpenCloud, or debugging sync, sign-in or roles."
---

# OpenCloud

[opencloud.nix](../../../modules/opencloud.nix) runs the production line of OpenCloud (files
only) and publishes `cloud.` through both proxies ([proxy skill](../proxy/SKILL.md)). Its
proxy speaks plain HTTP behind Caddy and its built-in identity provider is off: everyone signs in
through Authelia ([identity skill](../identity/SKILL.md)), which knows the web app and the
desktop, Android and iOS apps as public PKCE clients under OpenCloud's default client ids. A
first sign-in creates the account; the role comes from the person's Authelia groups
(`opencloudAdmin`, `opencloudUser`), and someone with no such group cannot sign in. App tokens
are off (the `auth-app` service and the proxy's app auth): a token signs in without Authelia's
second factor and outlives a lockout there.

Everything lives on `tank/opencloud` at `/srv/opencloud`, and both units refuse to start without
that mount. That includes `config/opencloud.yaml`, which the first start generates and which
holds the inter-service secrets and ids: it is not in Git or sops, so losing the dataset loses
the installation, and copying it is how a restore works. A production release is upgraded only
forward; moving to the rolling line and back is a downgrade OpenCloud does not support.

The desktop client is installed on every workstation (the `opencloud` cask on the mac). Sign-in
and the folder pairs are set in the client, whose token lives in the system keychain, so they are
not declared. On Linux it starts with the Fusion style, because Stylix's Kvantum has no QML
style and the client aborts under it.
