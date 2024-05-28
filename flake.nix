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
        peertube = pkgs.peertube.overrideAttrs (old: rec {
          src = ./.;
          version = "unstable";

          yarnOfflineCacheServer = pkgs.fetchYarnDeps {
            yarnLock = "${src}/yarn.lock";
            hash = "sha256-XjYg1+2GsPWheu9H3IAL8o+mxNVlvrpKj1xMqRJ7HUo=";
          };

          yarnOfflineCacheClient = pkgs.fetchYarnDeps {
            yarnLock = "${src}/client/yarn.lock";
            hash = "sha256-OjbzKZY8SvMF2rBxdwLNRCrURYQT9yh4GAXSguirtCI=";
          };

          yarnOfflineCacheAppsCli = pkgs.fetchYarnDeps {
            yarnLock = "${src}/apps/peertube-cli/yarn.lock";
            hash = "sha256-wBDFXHU/Sq7sueakE5g631bTNSGTPqaJu+jV1TL0rWo=";
          };

          yarnOfflineCacheAppsRunner = pkgs.fetchYarnDeps {
            yarnLock = "${src}/apps/peertube-runner/yarn.lock";
            hash = "sha256-LuLh/uiAIuFU6YRwsM0gyH1vr1GZZSOEY8q9gAHvbMY=";
          };

        });
        default = peertube;
      };
    };
}
