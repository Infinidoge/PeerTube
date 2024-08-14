{ nixosTest, peertube, yarnifyPlugin }:
nixosTest ({ pkgs, lib, ... }:
let
  pluginPath = pkg: "${pkg}/lib/node_modules/${pkg.pname}";
in
{
  name = "peertube";
  meta.maintainers = with pkgs.lib.maintainers; [ izorkin ];

  nodes = {
    database = {
      networking = {
        interfaces.eth1 = {
          ipv4.addresses = [
            { address = "192.168.2.10"; prefixLength = 24; }
          ];
        };
        firewall.allowedTCPPorts = [ 5432 31638 ];
      };

      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        ensureDatabases = [ "peertube_test" ];
        ensureUsers = [
          {
            name = "peertube_test";
            ensureDBOwnership = true;
          }
        ];
        authentication = ''
          hostnossl peertube_test peertube_test 192.168.2.11/32 md5
        '';
        initialScript = pkgs.writeText "postgresql_init.sql" ''
          CREATE ROLE peertube_test LOGIN PASSWORD '0gUN0C1mgST6czvjZ8T9';
        '';
      };

      services.redis.servers.peertube = {
        enable = true;
        bind = "0.0.0.0";
        requirePass = "turrQfaQwnanGbcsdhxy";
        port = 31638;
      };
    };

    server = { pkgs, config, ... }: {
      imports = [ ../module.nix ];
      disabledModules = [ "services/web-apps/peertube.nix" ];

      environment = {
        etc = {
          "peertube/password-init-root".text = ''
            PT_INITIAL_ROOT_PASSWORD=zw4SqYVdcsXUfRX8aaFX
          '';
          "peertube/secrets-peertube".text = ''
            063d9c60d519597acef26003d5ecc32729083965d09181ef3949200cbe5f09ee
          '';
          "peertube/password-posgressql-db".text = ''
            0gUN0C1mgST6czvjZ8T9
          '';
          "peertube/password-redis-db".text = ''
            turrQfaQwnanGbcsdhxy
          '';
        };
      };

      networking = {
        interfaces.eth1 = {
          ipv4.addresses = [
            { address = "192.168.2.11"; prefixLength = 24; }
          ];
        };
        extraHosts = ''
          192.168.2.11 peertube.local
        '';
        firewall.allowedTCPPorts = [ 9000 ];
      };

      systemd.tmpfiles.rules =
        let
          plugin = yarnifyPlugin {
            plugin = pkgs.peertube-plugin-hello-world;
            yarnLockHash = "sha256-l1yLJLaXFB1rcnx8BFIXdjQDIanzMY/54kupV/KgUGc=";
            yarnDepsHash = "sha256-8uH4Vn60joP2ZFybYuOvSPgJtzaMZt+rJJ/CBPaiZMA=";
          };
          plugins = pkgs.writers.writeJSON "declarative_plugins.json" {
            "peertube-plugin-hello-world" = {
              preInstall = "cp --no-preserve=mode ${plugin.yarnDeps} /var/lib/peertube/storage/plugins/.yarn-offline-cache";
              postInstall = "rm -rf /var/lib/peertube/storage/plugins/.yarn-offline-cache";
              pluginPath = pluginPath plugin;
              extraArgs = "--verbose --use-yarnrc ${pkgs.writeText "yarnrc" ''
                yarn-offline-mirror "/var/lib/peertube/storage/plugins/.yarn-offline-cache"
              ''}";
            };
          };
        in
        [
          "L+ '/var/lib/peertube/storage/plugins/declarative_plugins.json' 0700 ${config.services.peertube.user} ${config.services.peertube.group} - ${plugins}"
        ];

      services.peertube = {
        enable = true;
        package = peertube;
        localDomain = "peertube.local";
        enableWebHttps = false;

        serviceEnvironmentFile = "/etc/peertube/password-init-root";

        secrets = {
          secretsFile = "/etc/peertube/secrets-peertube";
        };

        database = {
          host = "192.168.2.10";
          name = "peertube_test";
          user = "peertube_test";
          passwordFile = "/etc/peertube/password-posgressql-db";
        };

        redis = {
          host = "192.168.2.10";
          port = 31638;
          passwordFile = "/etc/peertube/password-redis-db";
        };

        settings = {
          listen = {
            hostname = "0.0.0.0";
          };
          instance = {
            name = "PeerTube Test Server";
          };
        };
      };
    };

    client = {
      environment.systemPackages = [ pkgs.jq peertube.cli ];
      networking = {
        interfaces.eth1 = {
          ipv4.addresses = [
            { address = "192.168.2.12"; prefixLength = 24; }
          ];
        };
        extraHosts = ''
          192.168.2.11 peertube.local
        '';
      };
    };

  };

  testScript = ''
    start_all()

    database.wait_for_unit("postgresql.service")
    database.wait_for_unit("redis-peertube.service")

    database.wait_for_open_port(5432)
    database.wait_for_open_port(31638)

    server.wait_for_unit("peertube.service")
    server.wait_for_open_port(9000)

    server.wait_for_console_text("HTTP server listening on 0.0.0.0:9000")

    # Check if PeerTube is running
    client.succeed("curl --fail http://peertube.local:9000/api/v1/config/about | jq -r '.instance.name' | grep 'PeerTube\ Test\ Server'")

    # Check PeerTube CLI version
    client.succeed('peertube-cli auth add -u "http://peertube.local:9000" -U "root" --password "zw4SqYVdcsXUfRX8aaFX"')

    client.wait_until_succeeds('peertube-cli plugins list | grep "hello-world"', timeout=5)

    client.succeed('peertube-cli auth list | grep "http://peertube.local:9000"')
    client.succeed('peertube-cli auth del "http://peertube.local:9000"')
    client.fail('peertube-cli auth list | grep "http://peertube.local:9000"')

    client.shutdown()
    server.shutdown()
    database.shutdown()
  '';
})
