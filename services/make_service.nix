{
  name,
  description ? "${name} service",
  flake ? null,
  defaultPort ? 8080,
}:
{
  lib,
  config,
  pkgs,
  ...
}:

let
  thisService = config.moonix.services.${name};
  legalDbUsername = lib.replaceStrings [ "-" ] [ "_" ] name;
  dashServiceName = lib.replaceStrings [ "_" ] [ "-" ] name;
  service_name = "${name}-svc";
  service_user = "${legalDbUsername}_svc";
  secretsDir = "/run/${service_name}";
  secretFileEntries = lib.imap0(i: filename: {
    inherit filename;
    secretName = "moonix-${name}-file-${toString i}";
    credential_id = "file-${toString i}";
    target = "${secretsDir}/${filename}";
  }) (lib.attrNames thisService.secretFiles);
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
    secretFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {};
      description = "arbitraray files to be loaded to the service, they will be available at /run/${service_name}/secrets/<filename>";
    };
    # copies openssh flake settings partservice_user
    postgres = lib.mkOption {
      description = "postgresql configuration for '${name}' svc";
      default = {
        enable = false;
        databases = [];
      };
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
              default = [];
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
    tailscale = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "whether to expose the service through tailscale";
    };
    useUser = lib.mkOption {
      description = "whether to create a user for the service";
      default = {
        yes = false;
        data_path = "/var/lib/${name}-svc";
      };
      type = lib.types.submodule (
        { name, ... }: {
          options = {
            yes = lib.mkEnableOption "whether to create a user (and group) for the service";
            data_path = lib.mkOption {
              type = lib.types.path;
              description = "the home directory of the service user";
              default = "/var/lib/${name}-svc";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf thisService.enable {
    assertions = [
      {
        assertion = thisService.package != null;
        message = "you must provide a flake for the service '${name}' to run";
      }
    ];

    age.secrets = lib.listToAttrs (
      map (entry: lib.nameValuePair entry.secretName {
        file = thisService.secretFiles.${entry.filename};
      }) secretFileEntries
    );

    users.groups = lib.mkIf thisService.useUser.yes {
      services = {};
      "${service_user}" = {};
    };

    users.users.${service_user} = lib.mkIf thisService.useUser.yes {
      isSystemUser = true;
      shell = pkgs.fish;
      home = thisService.useUser.data_path;
      extraGroups = ["services"];
      group = service_user;
    };

    services.tailscale.serve.enable = lib.mkIf thisService.tailscale true;
    services.tailscale.serve.services."${dashServiceName}" = lib.mkIf thisService.tailscale {
      endpoints = {
        "tcp:${toString thisService.port}" = "http://localhost:${toString thisService.port}";
      };
    };

    services.postgresql = lib.mkIf thisService.postgres.enable {
      ensureDatabases = [ service_user ];
      ensureUsers = [
        {
          name = service_user;
          ensureDBOwnership = true;
        }
      ];
    };

    # https://wiki.nixos.org/wiki/Systemd/User_Services
    # https://search.nixos.org/options?query=systemd.user.services
    systemd.services.${service_name} = lib.mkIf thisService.enable {
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

        # https://gist.github.com/ageis/f5595e59b1cddb1513d1b425a323db04
        PrivateTmp = true;
        ProtectHome = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        LockPersonality = true;
        RestrictRealtime = true;
        PrivateDevices = true;

        EnvironmentFile = lib.mkIf (thisService.secretEnv != null) thisService.secretEnv;
        Environment = [
          "SVC_PORT=${toString thisService.port}"
        ] ++ lib.optionals (secretFileEntries != []) [
          "SVC_SECRETS_DIR=${secretsDir}"
        ];
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = "30s";
      } // lib.optionalAttrs (thisService.useUser.yes) {
        User = service_user;
        Group = service_user;
      } // lib.optionalAttrs (!thisService.useUser.yes) {
        DynamicUser = true;
        Group = service_user;
        StateDirectory = service_name;
        RuntimeDirectory = service_name;
      } // lib.optionalAttrs(secretFileEntries != []) {
        RuntimeDirectory = service_name;
        RuntimeDirectoryMode = "0700";
        WorkingDirectory = secretsDir;
        LoadCredential = map (
          entry: "${entry.credential_id}:${config.age.secrets.${entry.secretName}.path}"
        ) secretFileEntries;
        ExecStartPre = map (
          entry: "${pkgs.coreutils}/bin/install -D -m 0400 \${CREDENTIALS_DIRECTORY}/${entry.credential_id} ${lib.escapeShellArg entry.target}"
        ) secretFileEntries;
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
      before = [ "${service_name}.service" ];

      description = "postgresql db setup for ${service_name}";
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
          ${psql} postgres -tc "select 1 from pg_roles where rolname = '${service_user}'" | grep -q 1 || ${psql} postgres -c "create role ${service_user} with login"

          ${lib.concatMapStringsSep "\n" (
            db:
            let
              legalDbName = lib.replaceStrings [ "-" ] [ "_" ] db;
              fullDb = "${legalDbUsername}_${legalDbName}";
            in
            ''
              ${psql} postgres -tc "select 1 from pg_database where datname = '${fullDb}'" | grep -q 1 || ${psql} postgres -c "create database ${fullDb} owner ${service_user}"
              ${psql} ${fullDb} -c "revoke all on database ${fullDb} from public"
              ${psql} ${fullDb} -c "grant all on database ${fullDb} to ${service_user}"
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
