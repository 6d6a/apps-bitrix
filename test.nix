# Run virtual machine, then container with Apache and PHP, and test it.

{ nixpkgs
, bitrixArchive
, installBitrixScript
, phpRef ? "master"
, debug ? false
, phpVersion ? "php72"
, image
}:

with nixpkgs;
with lib;

let
  maketest = <nixpkgs/nixos/tests> + /make-test.nix;

  bitrixImage = import ./default.nix {
    inherit nixpkgs bitrixArchive installBitrixScript;
  };

  runBitrixImage = runBitrixDockerImage bitrixImage;

  runApacheDockerImage = image:
    writeScript "runDockerImage.sh" ''
      #!${bash}/bin/bash
      set -e -x
      rsync -av /etc/{passwd,group,shadow} /opt/etc/ > /dev/null
      ${docker}/bin/${
        (lib.importJSON
          (image.baseJson)).config.Labels."ru.majordomo.docker.cmd"
      } &
    '';

  runBitrixDockerImage = image:
    writeScript "runDockerImage.sh" ''
      #!${bash}/bin/bash
      set -e -x
      ${(lib.importJSON
        (image.baseJson)).config.Labels."ru.majordomo.docker.cmd"}
    '';

  runApacheContainer = runApacheDockerImage image;

  loadContainers = writeScript "pullContainers.sh" ''
    #!/bin/sh -eux
      ${
        builtins.concatStringsSep "; "
        (map (container: "${pkgs.docker}/bin/docker load --input ${container}")
          ([ image bitrixImage ] ++ map pkgs.dockerTools.pullImage testImages))
      }
  '';

  desktopEntry = import ./desktop-entry.nix;

in import maketest ({ pkgs, lib, ... }: {
  name = "bitrixMachine";
  nodes = {
    dockerNode = { pkgs, ... }: {
      virtualisation = {
        cores = 3;
        memorySize = 4 * 1024;
        diskSize = 4 * 1024;
        docker.enable = true;
        qemu.networkingOptions = if debug then [
          "-net nic,model=virtio"
          "-net user,hostfwd=tcp::2222-:22"
        ] else [
          "-net nic,model=virtio"
          "-net user"
        ];
      };

      networking.extraHosts = "127.0.0.1 bitrix.intr";
      users.users = {
        u12 = {
          isNormalUser = true;
          description = "Test user";
          password = "foobar";
          uid = 12345;
        };
        www-data = {
          isNormalUser = false;
          uid = 33;
        };
        admin = {
          isNormalUser = true;
          password = "admin";
          extraGroups = [ "wheel" "docker" ];
          openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC35V1L3xgGA7DIdUCRzLpOjeaUi+qt2Gb5DV67ifmyw5i7UH9onVen6FQKMkuQBn0hVu9h9XVV30lGtCXj7Des/FXpV9OW3MRbWKxmekDshZHu+QkhZer9i+Nd413Q+UDzJGANUwJ71mr3H3rqTDZnWN/LQGkGv8xR/mK4vWfAWgidi1sdABgoEh0gN80Oa2VMhsX0Nx2VmCv5k7mftajADKnTc6paZGzCaShNgTlExZEHRfUUqXb1Yk3gifIZNxhdbcplmRLeMccbYnv0i7cg8TekH+3VmeS+JWNYVHrxHuic/L9otSL7HXnmnlAawmMQLZPUTCIMQP4kWju7I0BGCC2tUpm8OZvxtXtbHjLk5oX+Oe66IV142ORwvH/mWnOWs9JeafcGpP1VerpBTmPeQi3flbKOGCAGCeQtnLO8XPIx6FzNAfzrJJX05tvzo5Hau9ukDwLEzk+0+fb1biJOqbYFdwoj/mFBIwKLzAoOGw2v7UZmLAzPUFaKiZki4NgRpq5Myrc1xcn39h5jjMZU1K29lVxbMjYE3ikHrUOEYCsPQwL5KEKVIQRqk6UZY4FxApeSgoiCftbWGXpjheCHOUyd9+MtlL/Q1aWbxkMT5eNmFvMVm7hfLZqXje0lAnJJOX+KgyoHnNqmAmZsauUreW/mfhTFHFTCG8wpW50s3w=="
          ];
        };
      };

      security.sudo.enable = true;
      security.sudo.extraConfig = ''
        admin  ALL=NOPASSWD: ALL
      '';

      services.xserver = {
        enable = if debug then true else false;
        desktopManager = {
          default = "xfce";
          xterm.enable = false;
          xfce.enable = true;
        };
      };

      services.xserver.displayManager.lightdm.autoLogin.enable =
        if debug then true else false;
      services.xserver.displayManager.lightdm.autoLogin.user = "admin";

      services.openssh.enable = if debug then true else false;
      services.openssh.permitRootLogin = if debug then "yes" else "no";
      services.openssh.extraConfig = ''
        PermitEmptyPasswords yes
      '';

      environment.systemPackages = with pkgs;
        [ tmux tree ] ++ optionals debug [
          firefox
          feh
          mycli
          xorg.xhost
          (desktopEntry {
            inherit pkgs;
            name = "run-apache";
            comment = "Run Apache in Docker container";
            command = "sh -c '/run/wrappers/bin/sudo -i ${
                runApacheDockerImage image
              }; read -p \"Press Enter to close.\"'";
            destination = "/share/applications/run-apache.desktop";
          })
          (desktopEntry {
            inherit pkgs;
            name = "install-bitrix";
            comment = "Run Apache in Docker container";
            command =
              "sh -c '/run/wrappers/bin/sudo -i ${runBitrixImage}; read -p \"Press Enter to close.\"'";
            destination = "/share/applications/install-bitrix.desktop";
          })
        ];
      environment.variables.SECURITY_LEVEL = "default";
      environment.variables.SITES_CONF_PATH =
        "/etc/apache2-${phpVersion}-default/sites-enabled";
      environment.variables.SOCKET_HTTP_PORT = "80";
      environment.interactiveShellInit = ''
        alias ll='ls -alF'
        alias s='sudo -i'
        alias show-tests='ls /nix/store/*{test,run}*{sh,py}'
        alias list-tests='ls /nix/store/*{test,run}*{sh,py}'
      '';
      boot.initrd.postMountCommands = ''
        for dir in /apache2-${phpVersion}-default /opcache /home \
                   /opt/postfix/spool/public /opt/postfix/spool/maildrop \
                   /opt/postfix/lib; do
            mkdir -p /mnt-root$dir
        done

        mkdir /mnt-root/apache2-${phpVersion}-default/sites-enabled

        # Used as Docker volume
        #
        mkdir -p /mnt-root/opt/etc
        for file in group gshadow passwd shadow; do
          mkdir -p /mnt-root/opt/etc
          cp -v /etc/$file /mnt-root/opt/etc/$file
        done
        #
        mkdir -p /mnt-root/opcache/bitrix.intr
        chmod -R 1777 /mnt-root/opcache

        mkdir -p /mnt-root/etc/apache2-${phpVersion}-default/sites-enabled/
        cat <<EOF > /mnt-root/etc/apache2-${phpVersion}-default/sites-enabled/5d41c60519f4690001176012.conf
        <VirtualHost 127.0.0.1:80>
            ServerName bitrix.intr
            ServerAlias www.bitrix.intr
            ScriptAlias /cgi-bin /home/u12/bitrix.intr/www/cgi-bin
            DocumentRoot /home/u12/bitrix.intr/www
            <Directory /home/u12/bitrix.intr/www>
                Options +FollowSymLinks -MultiViews +Includes -ExecCGI
                DirectoryIndex index.php index.html index.htm
                Require all granted
                AllowOverride all
            </Directory>
            AddDefaultCharset UTF-8
          UseCanonicalName Off
            AddHandler server-parsed .shtml .shtm
            php_admin_flag allow_url_fopen on
            php_admin_value mbstring.func_overload 0
            php_admin_value opcache.revalidate_freq 0
            php_admin_value opcache.file_cache "/opcache/bitrix.intr"
            <IfModule mod_setenvif.c>
                SetEnvIf X-Forwarded-Proto https HTTPS=on
                SetEnvIf X-Forwarded-Proto https PORT=443
            </IfModule>
            <IfFile  /home/u12/logs>
            CustomLog /home/u12/logs/www.bitrix.intr-access.log common-time
            ErrorLog /home/u12/logs/www.bitrix.intr-error_log
            </IfFile>
            MaxClientsVHost 20
            AssignUserID #12345 #100
        </VirtualHost>
        EOF

        mkdir -p /mnt-root/home/u12/bitrix.intr/www
        chown 12345:100 -R /mnt-root/home/u12
        mkdir -p /mnt-root/opt/run
      '';
      services.mysql.enable = true;
      services.mysql.initialScript = pkgs.writeText "mariadb-init.sql" ''
        ALTER USER root@localhost IDENTIFIED WITH unix_socket;
        DELETE FROM mysql.user WHERE password = ''' AND plugin = ''';
        DELETE FROM mysql.user WHERE user = ''';
        CREATE USER 'bitrix'@'localhost' IDENTIFIED BY 'qwerty123admin';
        FLUSH PRIVILEGES;
      '';
      services.mysql.ensureDatabases = [ "bitrix" ];
      services.mysql.ensureUsers = [{
        name = "bitrix";
        ensurePermissions = { "bitrix.*" = "ALL PRIVILEGES"; };
      }];
      services.mysql.package = pkgs.mariadb;
      environment.etc.testBitrix.source = runBitrixImage;
      environment.etc.dockerRunApache.source = runApacheContainer;
    };
  };

  testScript = [''
    print "Tests entry point.\n";
    startAll;

    print "Start services.\n";
    $dockerNode->waitForUnit("mysql");
    $dockerNode->sleep(10);
  ''] ++ [
    (dockerNodeTest {
      description = "Load containers";
      action = "succeed";
      command = loadContainers;
    })
    (dockerNodeTest {
      description = "Start Apache container";
      action = "succeed";
      command = runApacheContainer;
    })
    (dockerNodeTest {
      description = "Install Bitrix";
      action = "succeed";
      command = "${runBitrixImage}";
    })
    (dockerNodeTest {
      description = "Take Bitrix screenshot";
      action = "succeed";
      command = builtins.concatStringsSep " " [
        "${firefox}/bin/firefox"
        "--headless"
        "--screenshot=/tmp/xchg/coverage-data/bitrix.png"
        "http://bitrix.intr/"
      ];
    })
    (dockerNodeTest {
      description = "Run container structure test.";
      action = "succeed";
      command = containerStructureTest {
        inherit pkgs;
        config = ./container-structure-test.yaml;
        image = bitrixImage.imageName;
      };
    })
  ];
}) { }
