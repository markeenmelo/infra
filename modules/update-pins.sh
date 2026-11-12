caddy=modules/caddy.pkg.nix
while read -r module; do
  latest=$(curl -fsS "https://proxy.golang.org/$module/@latest" | jq -er .Version)
  sed -i "s|\"$module@[^\"]*\"|\"$module@$latest\"|" "$caddy"
done < <(grep -o 'github\.com/[^@"]*' "$caddy")

hub=$(git ls-remote https://github.com/crowdsecurity/hub HEAD | cut -f1)
[[ $hub =~ ^[0-9a-f]{40}$ ]]
sed -i "s/hub_branch = \"[0-9a-f]*\"/hub_branch = \"$hub\"/" modules/crowdsec.nix

dashboards=modules/grafana-dashboards.json
while read -r name; do
  id=$(jq -r --arg n "$name" '.[$n].id' "$dashboards")
  revision=$(curl -fsS "https://grafana.com/api/dashboards/$id" | jq -er '.revision | numbers')
  [ "$revision" = "$(jq -r --arg n "$name" '.[$n].revision' "$dashboards")" ] && continue
  hash=$(nix store prefetch-file --json "https://grafana.com/api/dashboards/$id/revisions/$revision/download" < /dev/null | jq -er .hash)
  jq --arg n "$name" --argjson r "$revision" --arg h "$hash" '.[$n] += { revision: $r, hash: $h }' "$dashboards" > "$dashboards.new"
  mv "$dashboards.new" "$dashboards"
done < <(jq -r 'keys[]' "$dashboards")
