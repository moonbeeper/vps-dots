{ ... }: {
  imports = [
    ../services/caddy.nix
    ../services/postgres.nix
    ../services/hi_world.nix
  ];

  moonix.services.hi_world = {
    enable = true;
  };
}
