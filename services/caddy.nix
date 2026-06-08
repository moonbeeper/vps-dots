{ config, pkgs, ... }:
{
  services.caddy = {
    enable = true;

    package = pkgs.caddy.withPlugins {
      plugins = [
        # does not like "https://" !!!
        "github.com/caddy-dns/cloudflare@v0.2.4"
      ];
      # to get it, just build with a dummy one and copy the real one that it gives you
      hash = "sha256-8yZDrejNKsaUnUaTUFYbarWNmxafqp2z2rWo+XRsxV8=";
    };
    globalConfig = ''
      acme_dns cloudflare {env.CF_API_TOKEN}
    '';
    email = "moonbeeper@duck.com";
  };

  systemd.services.caddy.serviceConfig = {
    EnvironmentFile = config.age.secrets.caddy_cloudflare.path;
  };
}
