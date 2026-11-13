{ caddy }:
caddy.withPlugins {
  plugins = [
    "github.com/caddy-dns/porkbun@v0.3.1"
    "github.com/porech/caddy-maxmind-geolocation@v1.0.3"
    "github.com/mholt/caddy-ratelimit@v0.1.0"
  ];
  hash = "sha256-1QwFhDKCDZQIbsIkUc3hE++jLuFZrFUPtG6BPyf9b9I=";
}
