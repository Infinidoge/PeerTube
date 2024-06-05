{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    ngipkgs.url = "github:ngi-nix/ngipkgs/init/peertube-plugins/hello-world";
    ngipkgs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ flake-parts, self, nixpkgs, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [
      "x86_64-linux"
    ];

    flake = {
      nixosModules.default = ./nix/module.nix;
    };

    perSystem = { system, config, pkgs, ... }: {
      _module.args.pkgs = import nixpkgs {
        inherit system;
        overlays = [
          inputs.ngipkgs.overlays.default
        ];
      };
      packages = rec {
        bcrypt = pkgs.callPackage ./nix/bcrypt.nix { };
        peertube = pkgs.callPackage ./nix/derivation.nix { bcryptLib = bcrypt; };
        default = peertube;
      };
      checks = {
        inherit (config.packages) peertube;
        inherit (config.packages.peertube.tests) simple declarativePlugins;
      };
    };
  };
}
