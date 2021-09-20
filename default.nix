{ nixpkgs
, bitrixArchive
, installBitrixScript
, dbName ? "bitrix"
, dbPassword ? "qwerty123admin"
, dbUser ? "bitrix"
, dbHost ? "127.0.0.1"
, adminPassword ? "qwerty123admin"
, adminUsername ? "admin"
, adminEmail ? "root@example.com"
, appTitle ? "bitrix"
, domainName ? "bitrix.intr"
, workdir ? "/home/u12/${domainName}/www"
, user ? "12345"
, group ? "100"
}:

with nixpkgs;

with lib;

pkgs.dockerTools.buildLayeredImage rec {
  name = "docker-registry.intr/apps/bitrix-start";
  tag = "latest";
  contents = [
    mj-phantomjs
    bashInteractive
    coreutils
    fontconfig.out
    shared_mime_info
    (python3.withPackages
      (python-packages: with python-packages; [ pymysql selenium ]))
    installBitrixScript
  ];
  config = {
    Entrypoint =
      [ "${installBitrixScript}/bin/bitrix_install" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LOCALE_ARCHIVE=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.cmd = builtins.concatStringsSep " " [
        "docker"
        "run"
        "--user"
        "${user}:${group}"
        "--volume"
        "${workdir}:/workdir"
        "--env"
        "DB_NAME=${dbName}"
        "--env"
        "DB_PASSWORD=${dbPassword}"
        "--env"
        "DB_USER=${dbUser}"
        "--env"
        "DB_HOST=${dbHost}"
        "--env"
        "ADMIN_PASSWORD=${adminPassword}"
        "--env"
        "ADMIN_USERNAME=${adminUsername}"
        "--env"
        "ADMIN_EMAIL=${adminEmail}"
        "--env"
        "APP_TITLE=${appTitle}"
        "--env"
        "DOMAIN_NAME=${domainName}"
        "--network=host"
        "--rm"
        "--workdir" # Hack to set user with uid '12345' owner of '/workdir' directory.
        "/workdir"
        "docker-registry.intr/apps/bitrix-start:latest"
      ];
    };
    WorkingDir = "/workdir";
  };
  extraCommands = ''
    set -x -e

    mkdir -p {etc,home/alice,root,tmp}
    chmod 755 etc
    chmod 777 home/alice
    chmod 777 tmp

    cat > etc/passwd << 'EOF'
    root:!:0:0:System administrator:/root:/bin/sh
    alice:!:1000:997:Alice:/home/alice:/bin/sh
    EOF

    cat > etc/group << 'EOF'
    root:!:0:
    users:!:997:
    EOF

    cat > etc/nsswitch.conf << 'EOF'
    hosts: files dns
    EOF

    cp ${bitrixArchive} bitrix-20.0.180.tgz
  '';
}
