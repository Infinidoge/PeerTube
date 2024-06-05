{ lib
, stdenv
, fetchYarnDeps
, callPackage
, brotli
, fixup-yarn-lock
, jq
, fd
, nodejs
, which
, yarn
, bcryptLib
}:
stdenv.mkDerivation (finalAttrs: rec {
  pname = "peertube";
  version = "unstable";

  src = lib.cleanSourceWith {
    src = ./..;
    filter = name: type:
      let baseName = baseNameOf (toString name); in !(
        (baseName == "nix" && type == "directory")
      );
  };

  yarnOfflineCacheServer = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-cF8ZbAepWb53wQlqQRZEc7/DUSUqOkZsmHoltKW8d7Y=";
  };

  yarnOfflineCacheClient = fetchYarnDeps {
    yarnLock = "${src}/client/yarn.lock";
    hash = "sha256-OjbzKZY8SvMF2rBxdwLNRCrURYQT9yh4GAXSguirtCI=";
  };

  yarnOfflineCacheAppsCli = fetchYarnDeps {
    yarnLock = "${src}/apps/peertube-cli/yarn.lock";
    hash = "sha256-wBDFXHU/Sq7sueakE5g631bTNSGTPqaJu+jV1TL0rWo=";
  };

  yarnOfflineCacheAppsRunner = fetchYarnDeps {
    yarnLock = "${src}/apps/peertube-runner/yarn.lock";
    hash = "sha256-LuLh/uiAIuFU6YRwsM0gyH1vr1GZZSOEY8q9gAHvbMY=";
  };

  outputs = [ "out" "cli" "runner" ];

  nativeBuildInputs = [ brotli fixup-yarn-lock jq which yarn fd ];

  buildInputs = [ nodejs ];

  buildPhase = ''
    # Build node modules
    export HOME=$PWD
    fixup-yarn-lock ~/yarn.lock
    fixup-yarn-lock ~/client/yarn.lock
    fixup-yarn-lock ~/apps/peertube-cli/yarn.lock
    fixup-yarn-lock ~/apps/peertube-runner/yarn.lock
    yarn config --offline set yarn-offline-mirror $yarnOfflineCacheServer
    yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts --no-progress
    cd ~/client
    yarn config --offline set yarn-offline-mirror $yarnOfflineCacheClient
    yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts --no-progress
    cd ~/apps/peertube-cli
    yarn config --offline set yarn-offline-mirror $yarnOfflineCacheAppsCli
    yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts --no-progress
    cd ~/apps/peertube-runner
    yarn config --offline set yarn-offline-mirror $yarnOfflineCacheAppsRunner
    yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts --no-progress

    patchShebangs ~/{node_modules,client/node_modules,/apps/peertube-cli/node_modules,apps/peertube-runner/node_modules,scripts}

    # Fix bcrypt node module
    cd ~/node_modules/bcrypt
    if [ "${bcryptLib.version}" != "$(cat package.json | jq -r .version)" ]; then
      echo "Mismatching version please update bcrypt in derivation"
      exit
    fi
    mkdir -p ./lib/binding && tar -C ./lib/binding -xf ${bcryptLib}

    # Return to home directory
    cd ~

    # Build PeerTube server
    npm run build:server

    # Build PeerTube client
    npm run build:client

    # Build PeerTube cli
    npm run build:peertube-cli
    patchShebangs ~/apps/peertube-cli/dist/peertube.js

    # Build PeerTube runner
    npm run build:peertube-runner
    patchShebangs ~/apps/peertube-runner/dist/peertube-runner.js

    # Clean up declaration files
    find ~/dist/ \
      ~/packages/core-utils/dist/ \
      ~/packages/ffmpeg/dist/ \
      ~/packages/models/dist/ \
      ~/packages/node-utils/dist/ \
      ~/packages/server-commands/dist/ \
      ~/packages/typescript-utils/dist/ \
      \( -name '*.d.ts' -o -name '*.d.ts.map' \) -type f -delete
  '';

  installPhase = ''
    mkdir -p $out/dist
    mv ~/dist $out
    mv ~/node_modules $out/node_modules
    mkdir $out/client
    mv ~/client/{dist,node_modules,package.json,yarn.lock} $out/client
    mkdir -p $out/packages/{core-utils,ffmpeg,models,node-utils,server-commands,typescript-utils}
    mv ~/packages/core-utils/{dist,package.json} $out/packages/core-utils
    mv ~/packages/ffmpeg/{dist,package.json} $out/packages/ffmpeg
    mv ~/packages/models/{dist,package.json} $out/packages/models
    mv ~/packages/node-utils/{dist,package.json} $out/packages/node-utils
    mv ~/packages/server-commands/{dist,package.json} $out/packages/server-commands
    mv ~/packages/typescript-utils/{dist,package.json} $out/packages/typescript-utils
    mv ~/{config,support,CREDITS.md,FAQ.md,LICENSE,README.md,package.json,yarn.lock} $out

    mkdir -p $cli/bin
    mv ~/apps/peertube-cli/{dist,node_modules,package.json,yarn.lock} $cli
    ln -s $cli/dist/peertube.js $cli/bin/peertube-cli

    mkdir -p $runner/bin
    mv ~/apps/peertube-runner/{dist,node_modules,package.json,yarn.lock} $runner
    ln -s $runner/dist/peertube-runner.js $runner/bin/peertube-runner

    # Create static gzip and brotli files
    fd -e css -e eot -e html -e js -e json -e svg -e webmanifest -e xlf \
      --type file --search-path $out/client/dist \
      --exec gzip -9 -n -c {} > {}.gz \;\
      --exec brotli --best -f {} -o {}.br
  '';

  passthru.tests = let peertube = finalAttrs.finalPackage; in {
    simple = callPackage ./tests/simple.nix { inherit peertube; };
    declarativePlugins = callPackage ./tests/declarativePlugins.nix { inherit peertube; };
  };


  meta = with lib; {
    description = "A free software to take back control of your videos";
    longDescription = ''
      PeerTube aspires to be a decentralized and free/libre alternative to video
      broadcasting services.
      PeerTube is not meant to become a huge platform that would centralize
      videos from all around the world. Rather, it is a network of
      inter-connected small videos hosters.
      Anyone with a modicum of technical skills can host a PeerTube server, aka
      an instance. Each instance hosts its users and their videos. In this way,
      every instance is created, moderated and maintained independently by
      various administrators.
      You can still watch from your account videos hosted by other instances
      though if the administrator of your instance had previously connected it
      with other instances.
    '';
    license = licenses.agpl3Plus;
    homepage = "https://joinpeertube.org/";
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
})
