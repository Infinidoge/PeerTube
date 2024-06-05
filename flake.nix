{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = inputs@{ flake-parts, self, nixpkgs, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [
      "x86_64-linux"
    ];

    flake = {
      nixosModules.default = ./nix/module.nix;
    };

    perSystem = { config, pkgs, ... }: {
      packages = rec {
        bcrypt = pkgs.callPackage ./nix/bcrypt.nix { };
        peertube = pkgs.callPackage ./nix/derivation.nix { bcryptLib = bcrypt; };
        default = peertube;
      };
      checks = {
        inherit (config.packages) peertube;
        inherit (config.packages.peertube.tests) simple;
      };
    };
  };
}
