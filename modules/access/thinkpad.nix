{
  # Real account review, 2026-09-10; see the partial preflight in docs/hosts.md.
  # UID/home/Zsh and the selected public key match the installed account. The
  # operator confirmed password console access; private comparison matched the
  # encrypted hash to both /etc/shadow and its early runtime file. Target root
  # stays locked, SSH key-only, Nix trust root-only and sudo authenticated.
  # Scanner/lp access is the already-approved printing/scanning configuration.
  # This does not acknowledge identity recovery, migration or desktop acceptance.
  fleet.hosts.thinkpad.module.fleet.workstation.usersReviewed = true;
}
