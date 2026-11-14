GITHUB_TOKEN=${GITHUB_TOKEN:-$(gh auth token 2>/dev/null || true)}
export GITHUB_TOKEN

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

for project in opentofu/*/; do
  main=${project}main.tf
  sources=$(grep -oP '^\s*source\s*=\s*"\K[^"]+' "$main")
  while read -r source; do
    latest=$(curl -fsS "https://registry.opentofu.org/v1/providers/$source/versions" |
      jq -er '[.versions[].version | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))] | sort_by(split(".") | map(tonumber)) | last')
    sed -i "\|source *= \"$source\"|{n;s|version *= \"~> [^\"]*\"|version = \"~> $latest\"|}" "$main"
    grep -qF "version = \"~> $latest\"" "$main"
  done <<< "$sources"
  rm -f "${project}.terraform.lock.hcl"
  tofu -chdir="$project" providers lock -platform=linux_amd64 -platform=darwin_arm64
done

pinact run --update
