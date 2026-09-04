{ ... }: {
  imports = [
    ../services/caddy.nix
    ../services/postgres.nix
    ../services/motd.nix
    ../services/hi_world.nix
    ../services/tailscale.nix
  ];

  moonix.services.hi_world = {
    enable = true;
  };
}
