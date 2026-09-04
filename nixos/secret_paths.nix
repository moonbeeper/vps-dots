{ ... }: {
  age.secrets.caddy_cloudflare.file = ../secrets/caddy_cloudflare.age;
  age.secrets.caddy_cloudflare.owner = "caddy";
  age.secrets.tailscale_authkey.file = ../secrets/tailscale_authkey.age;
}
