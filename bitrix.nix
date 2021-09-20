{ stdenv, cacert, fetchgit }:

stdenv.mkDerivation {
  name = "bitrix-20.0.180.tgz";
  version = "20.0.180";
  src = fetchgit {
    url = "https://gitlab.intr/apps/bitrix-start.git";
    # Previous commit before 'dist' directory update.
    rev = "fa2cc92dce298571ef2d21a39c7e391e91a3ffee";
    sha256 = "1wbf2bm061mzba0aqycnwbdmyl0im7vvzb833zzln0psc6jz2w4n";
  };
  prePatch = "cd dist"; # PHP code directory is not in root of the source.
  patches = [ ./patch/site_checker.patch ];
  installPhase = ''
    tar czf $out .
  '';
}
