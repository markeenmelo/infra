github_token=${GITHUB_TOKEN:-$(gh auth token 2> /dev/null || true)}

caddy=modules/caddy.pkg.nix
modules=$(grep -o 'github\.com/[^@"]*' "$caddy")
while read -r module; do
  latest=$(curl -fsS "https://proxy.golang.org/$module/@latest" | jq -er .Version)
  sed -i "s|\"$module@[^\"]*\"|\"$module@$latest\"|" "$caddy"
  grep -qF "\"$module@$latest\"" "$caddy"
done <<< "$modules"

hub=$(git ls-remote https://github.com/crowdsecurity/hub HEAD | cut -f1)
[[ $hub =~ ^[0-9a-f]{40}$ ]]
sed -i "s/hub_branch = \"[0-9a-f]*\"/hub_branch = \"$hub\"/" modules/crowdsec.nix
grep -qF "hub_branch = \"$hub\"" modules/crowdsec.nix

dashboards=modules/grafana-dashboards.json
names=$(jq -er 'keys[]' "$dashboards")
while read -r name; do
  id=$(jq -r --arg n "$name" '.[$n].id' "$dashboards")
  revision=$(curl -fsS "https://grafana.com/api/dashboards/$id" | jq -er '.revision | numbers')
  [ "$revision" = "$(jq -r --arg n "$name" '.[$n].revision' "$dashboards")" ] && continue
  hash=$(nix store prefetch-file --json "https://grafana.com/api/dashboards/$id/revisions/$revision/download" < /dev/null | jq -er .hash)
  jq --arg n "$name" --argjson r "$revision" --arg h "$hash" '.[$n] += { revision: $r, hash: $h }' "$dashboards" > "$dashboards.new"
  mv "$dashboards.new" "$dashboards"
done <<< "$names"

release() {
  local repo=$1 input=$2 tag
  tag=$(curl -fsS ${github_token:+-H "Authorization: Bearer $github_token"} "https://api.github.com/repos/$repo/releases/latest" | jq -er .tag_name)
  [[ $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
  sed -i "s|\"github:$repo/v[^\"]*\"|\"github:$repo/$tag\"|" flake.nix
  grep -qF "\"github:$repo/$tag\"" flake.nix
  nix flake update "$input"
}
release NousResearch/hermes-agent hermes-agent
release getpaseo/paseo paseo
release denful/import-tree import-tree
release serokell/deploy-rs deploy-rs

GITHUB_TOKEN=$github_token pinact run --update

update_providers() {
  local failed=0 project main lock before saved sources source latest
  for project in opentofu/*/; do
    main=${project}main.tf
    lock=${project}.terraform.lock.hcl
    before=$(cat "$main")
    saved=$(mktemp -d)
    cp "$main" "$saved/main.tf"
    [ ! -e "$lock" ] || cp "$lock" "$saved/lock"
    sources=$(grep -oP '^\s*source\s*=\s*"\K[^"]+' "$main")
    while read -r source; do
      latest=$(curl -fsS "https://registry.opentofu.org/v1/providers/$source/versions" |
        jq -er '[.versions[].version | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))] | sort_by(split(".") | map(tonumber)) | last')
      sed -i "\|source *= \"$source\"|{n;s|version *= \"~> [^\"]*\"|version = \"~> $latest\"|}" "$main"
      grep -qF "version = \"~> $latest\"" "$main"
    done <<< "$sources"
    [ "$(cat "$main")" = "$before" ] || rm -f "$lock"
    if ! tofu -chdir="$project" providers lock -platform=linux_amd64 -platform=linux_arm64 ||
      ! tofu -chdir="$project" init -backend=false -input=false -lockfile=readonly ||
      ! tofu -chdir="$project" validate; then
      cp "$saved/main.tf" "$main"
      rm -f "$lock"
      [ ! -e "$saved/lock" ] || cp "$saved/lock" "$lock"
      echo "update-pins: ${project} does not validate after the provider bump; reverted it, edit main.tf by hand" >&2
      failed=1
    fi
    rm -rf "$saved"
  done
  return "$failed"
}
