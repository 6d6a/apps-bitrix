{
  description = "Bitrix flake";

  inputs.nixpkgs = { url = "nixpkgs/nixos-20.03"; flake = false; };
  inputs.majordomo.url = "git+https://gitlab.intr/_ci/nixpkgs";
  inputs.apache2-php72.url = "git+https://gitlab.intr/webservices/apache2-php72?ref=flake";

  outputs = { self, nixpkgs, majordomo, apache2-php72 }: let
    system = "x86_64-linux";
    withMajordomoCacert = with majordomo.nixpkgs; rec {
      fetchgit-with-majordomo-cacert =
        fetchgit.override { cacert = nss-certs; };
      bitrixArchive = (callPackage ./bitrix.nix {
        cacert = nss-certs;
        fetchgit = fetchgit-with-majordomo-cacert;
      });
      installBitrixScript = (callPackage ./install.nix {
        cacert = nss-certs;
        fetchgit = fetchgit-with-majordomo-cacert;
      });
    };
  in {
    packages.x86_64-linux = {
      container = import ./default.nix {
        inherit (majordomo) nixpkgs;
        inherit (withMajordomoCacert) bitrixArchive installBitrixScript;
      };
      deploy = majordomo.outputs.deploy { tag = "apps/bitrix-start"; };
    };

    checks.x86_64-linux.apache2-php72 = import ./test.nix {
      inherit (majordomo) nixpkgs;
      inherit (withMajordomoCacert) bitrixArchive installBitrixScript;
      image = apache2-php72.outputs.packages.x86_64-linux.container;
    };

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.container;
  };
}
