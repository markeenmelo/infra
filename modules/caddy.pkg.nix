{ caddy }:
caddy.withPlugins {
  plugins = [
    "github.com/caddy-dns/porkbun@v0.3.1"
    "github.com/porech/caddy-maxmind-geolocation@v1.0.3"
  ];
  hash = "sha256-oIhRCKOI8zD5BTIZcoZgEi/wfj7BTvm+Hqpu/LwrLPA=";
}
