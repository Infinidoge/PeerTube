{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux = rec {
        bcrypt = pkgs.callPackage ./nix/bcrypt.nix { };
        peertube = pkgs.callPackage ./nix/derivation.nix { bcryptLib = bcrypt; };
        default = peertube;
      };
    };
}
