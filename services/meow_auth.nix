{ inputs, pkgs, lib, ... }:
let
  makeService = import ./make_service.nix;
  pack = makeService {
    name = "meow_auth2";
    description = "meow_auth2 service service";
    flake = inputs.meow_auth.packages.${pkgs.stdenv.hostPlatform.system}.default;
    defaultPort = 8080;
  };
in
{
  imports = [ pack ]; # wtf, what a workaround
  moonix.services.meow_auth2 = {
    postgres = {
      enable = true;
      databases = ["main"];
    };
    useUser.yes = true;
    secretFiles = {
      "production.toml" = ../secrets/meow_auth.age;
    };
    domain = "auth-backboard.meowish.net";
  };

  systemd.services."meow_auth2-migrate" = {
    wantedBy = [ "multi-user.target" ];
    after = [ "postgresql.service" "meow_auth2-db-setup.service" ];
    requires = [ "postgresql.service" "meow_auth2-db-setup.service" ];
    before = [ "meow_auth2-svc.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = "meow_auth2_svc";
      Group = "meow_auth2_svc";
      Environment = [
        "DATABASE_URL=postgres:///?host=/run/postgresql&user=meow_auth2_svc&dbname=meow_auth2_main"
      ];
      ExecStart = "${lib.getExe pkgs.sqlx-cli} migrate run --source ${inputs.meow_auth.outPath}/migrations";
    };
  };

  systemd.services."meow_auth2-svc".serviceConfig.Environment = [
    "WORK_ENV=production"
    "MEOW__DATABASE__URL=postgres:///?host=/run/postgresql&user=meow_auth2_svc&dbname=meow_auth2_main"
  ];
  systemd.services."meow_auth2-svc".preStart = "${pkgs.coreutils}/bin/touch .env";
}
