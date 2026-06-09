{
  name,
  description ? "${name} service",
  flake ? null,
  defaultPort ? 8080,
  postgres ? {
    enable = false;
    databases = [ ];
  },
}:
{
  lib,
  config,
  ...
}:

let
  thisService = config.moonix.services.${name};
  legalDbUsername = lib.replaceStrings [ "-" ] [ "_" ] name;
in
{
  options.moonix.services.${name} = {
    # stuff like starship sets its enable option to something akin to a description
    enable = lib.mkEnableOption description;
    port = lib.mkOption {
      type = lib.types.port;
      default = defaultPort;
      description = "the port that '${name}' svc will listen on";
    };
    domain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "the domain that '${name}' svc will be publicly available at";
    };
    secretEnv = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "the path to the agenix secret file that will be loaded to the env of the service";
    };
    # copies openssh flake settings part
    postgres = lib.mkOption {
      description = "postgresql configuration for '${name}' svc";
      default = postgres;
      type = lib.types.submodule (
        { name, ... }: {
          options = {
            # this would create an user for the service
            enable = lib.mkEnableOption "enable postgresql for '${name}' svc";
            databases = lib.mkOption {
              # copies the trusted-users thingy on the nix config
              type = lib.types.listOf lib.types.str;
              # soo this means if I remove one database, i will need to manually remove it from the db ;(
              description = "the list of databases to create for '${name}' svc, they will be prefixed with the service name";
              example = [
                "db1"
                "db2"
              ];
              default = postgres.databases;
            };
          };
        }
      );
    };
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = flake;
      description = "the nix package to run";
    };
  };

  config = lib.mkIf thisService.enable {
    assertions = [
      {
        assertion = flake != null;
        message = "you must provide a flake for the service '${name}' to run";
      }
    ];

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "${legalDbUsername}_svc" ];
      ensureUsers = [
        {
          name = "${legalDbUsername}_svc";
          ensureDBOwnership = true;
        }
      ];
    };

    # https://wiki.nixos.org/wiki/Systemd/User_Services
    # https://search.nixos.org/options?query=systemd.user.services
    systemd.services."${name}-svc" = lib.mkIf thisService.enable {
      wantedBy = [
        "multi-user.target"
      ]
      ++ lib.optionals thisService.postgres.enable [ "postgresql.service" ]; # idk about this
      requires = lib.optionals thisService.postgres.enable [ "postgresql.service" ];
      after = [
        "network.target"
      ]
      ++ lib.optionals thisService.postgres.enable [ "${name}-db-setup.service" ];

      description = description;
      serviceConfig = {
        ExecStart = "${lib.getExe thisService.package}";

        DynamicUser = true;
        StateDirectory = "${name}-svc";
        RuntimeDirectory = "${name}-svc";

        # https://gist.github.com/ageis/f5595e59b1cddb1513d1b425a323db04
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        LockPersonality = true;
        RestrictRealtime = true;
        PrivateDevices = true;

        EnvironmentFile = lib.mkIf (thisService.secretEnv != null) thisService.secretEnv;
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "30s";
      };
    };

    systemd.services."${name}-db-setup" = lib.mkIf (thisService.enable && thisService.postgres.enable) {
      wantedBy = [
        "multi-user.target"
      ];
      bindsTo = [ "postgresql.service" ];
      after = [
        "network.target"
        "postgresql.service"
      ];
      before = [ "${name}-svc.service" ];

      description = "postgresql db setup for ${name}-svc";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true; # appear as active when it already runs for like 1s lol
        User = "postgres";
      };
      # using -t gives the row without the headings. i mean, without saying for example ?column? and (1 row) after searching. its for grep.
      script =
        let
          psql = "${config.services.postgresql.package}/bin/psql";
        in
        ''
          ${psql} postgres -tc "select 1 from pg_roles where rolname = '${legalDbUsername}_svc'" | grep -q 1 || ${psql} postgres -c "create role ${legalDbUsername}_svc with login"

          ${lib.concatMapStringsSep "\n" (
            db:
            let
              legalDbName = lib.replaceStrings [ "-" ] [ "_" ] db;
              fullDb = "${legalDbUsername}_${legalDbName}";
            in
            ''
              ${psql} postgres -tc "select 1 from pg_database where datname = '${fullDb}'" | grep -q 1 || ${psql} postgres -c "create database ${fullDb} owner ${legalDbUsername}_svc"
              ${psql} ${fullDb} -c "revoke all on database ${fullDb} from public"
              ${psql} ${fullDb} -c "grant all on database ${fullDb} to ${legalDbUsername}_svc"
            ''
          ) thisService.postgres.databases}
        '';
    };

    services.caddy.virtualHosts = lib.mkIf (thisService.enable && thisService.domain != null) {
      "${thisService.domain}" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CF_API_TOKEN}
          }
          reverse_proxy localhost:${toString thisService.port}
        '';
      };
    };
  };
}
