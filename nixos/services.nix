{ ... }: {
  imports = [
    ../services/caddy.nix
    ../services/postgres.nix
    ../services/motd.nix
    ../services/hi_world.nix
    ../services/tailscale.nix
    ../services/meow_auth.nix
  ];

  moonix.services.hi_world = {
    enable = false;
  };
  moonix.services.meow_auth2 = {
    enable = true;
  };
}
