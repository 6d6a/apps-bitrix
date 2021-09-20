{ stdenv, cacert, fetchgit, lib, python3Packages }:

python3Packages.buildPythonPackage rec {
  pname = "bitrix-install.py";
  version = "0.0.1";
  src = fetchgit {
    url = "https://gitlab.intr/apps/bitrix-start.git";
    rev = "fa2cc92dce298571ef2d21a39c7e391e91a3ffee";
    sha256 = "1wbf2bm061mzba0aqycnwbdmyl0im7vvzb833zzln0psc6jz2w4n";
  };
  propagatedBuildInputs = [ python3Packages.pymysql python3Packages.selenium ];
}
