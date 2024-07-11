{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    ngipkgs.url = "github:ngi-nix/ngipkgs/init/peertube-plugins/hello-world";
    ngipkgs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ flake-parts, self, nixpkgs, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [
      "x86_64-linux"
    ];

    imports = [
      inputs.devshell.flakeModule
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
        peertube = pkgs.callPackage ./nix/derivation.nix { bcryptLib = bcrypt; inherit yarnifyPlugin; };
        default = peertube;
        inherit (pkgs) peertube-plugin-hello-world;

        yarnifyPlugin = pkgs.callPackage ./nix/yarnifyPlugin.nix { };
      };

      checks = {
        inherit (config.packages) peertube;
        inherit (config.packages.peertube.tests) simple declarativePlugins;
      };

      devshells.default = {
        devshell.packages = with pkgs; [
          nodejs
          yarn
        ];
      };
    };
  };
}
