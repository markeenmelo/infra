# Identity

[authelia.nix](../../../modules/authelia.nix) runs the portal every app's single sign-on
redirects to. Both of bastion's proxies forward `auth.` to its port on loopback
([proxy skill](../proxy/SKILL.md)), and the firewall opens that port on no interface.

Authelia is also the OIDC provider. An app module declares its client in `fleet.oidc.clients.ID`
(Authelia's client schema); every client gets the `people` policy (two factors, only the people
in the module), S256 PKCE and `openid profile email`, and a confidential one reads its pbkdf2
digest from `authelia/ID-client-secret-hash` while the app holds the plaintext under its own
key. The tokens are signed with `authelia/oidc-signing-key` and `authelia/oidc-hmac`; replacing
either signs every app out. The `authelia-HOST` check fails a client that drops the policy or
PKCE, or redirects anywhere but https, a native app's loopback (`http://127.0.0.1`,
`http://localhost`) or an app's own scheme. A client that must
stay signed in while its machine sleeps sets `lifespan = "sync"`, the module's long refresh token;
every other client keeps Authelia's default lifespans. A person's groups in the module become the `groups`
claim, which is how apps such as OpenCloud and Jellyfin assign roles.

People live in the module with their name and groups; their email and argon2 hash are
`authelia/USER-email` and `authelia/USER-password-hash` in `secrets/hosts/bastion.yaml`, rendered with them into the users
file Authelia reads read-only. So the portal offers no password reset or change: a person types
a new password into the hash command in the operator's private terminal, and the operator
deploys.

```sh
read -rs pw && printf %s "$pw" |
  nix run nixpkgs#libargon2 -- "$(openssl rand -hex 16)" -id -t 3 -m 16 -p 4 -l 32 -e | jq -R . |
  sops set --value-stdin secrets/hosts/bastion.yaml '["authelia"]["USER-password-hash"]'; unset pw
```

That is Authelia's default argon2id.

Two-factor registrations, sessions and bans are in the `authelia-main` database of the shared
[PostgreSQL](../../../modules/postgresql.nix), encrypted with `authelia/storage`; losing that key
loses every registration. PostgreSQL 17 keeps its data on `apps/postgresql` and refuses to start
without `PG_VERSION` there, so a missing pool never initializes an empty cluster. A major
version bump is a dump and restore, never a package change alone. Mail (identity checks for new
devices) goes out through the disroot account with `authelia/smtp-password`. Authelia does not
test that account when it starts: the test is fatal, so a mail server that refuses a connection
for a minute would fail a deploy and keep sign-in down after a reboot. A wrong password or
address shows only when a mail is sent. The
`authelia-HOST` check runs `validate-config` on the generated configuration with dummy secrets.
