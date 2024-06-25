{ stdenvNoCC
, cacert
, yarn
, fixup-yarn-lock
, fetchYarnDeps
, lib
}:

{ plugin, yarnLockHash ? "", yarnDepsHash ? "", ... }@args:

let
  # Separate in case it needs to be extracted to use elsewhere
  generateYarnLock = { src, hash ? "", ... }@args: stdenvNoCC.mkDerivation ({
    name = "yarn.lock";
    inherit src;

    GIT_SSL_CAINFO = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    NODE_EXTRA_CA_CERTS = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    nativeBuildInputs = [ cacert yarn ];

    dontInstall = true;

    buildPhase = ''
      runHook preBuild

      yarn import

      cp yarn.lock $out

      runHook postBuild
    '';

    outputHashAlgo = if hash != "" then null else "sha256";
    outputHash = hash;
  } // (removeAttrs args [ "src" "hash" ]));

  yarnLock = generateYarnLock ({
    inherit (plugin) src;
    hash = yarnLockHash;
  } // lib.optionalAttrs (plugin ? sourceRoot) { inherit (plugin) sourceRoot; });
in
plugin.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [ fixup-yarn-lock ];
  postInstall = lib.optionalString (old ? postInstall) old.postInstall + ''
    cp --no-preserve=mode ${yarnLock} $out/lib/node_modules/${plugin.pname}/yarn.lock
    fixup-yarn-lock $out/lib/node_modules/${plugin.pname}/yarn.lock
  '';
  passthru = lib.optionalAttrs (old ? passthru) old.passthru // {
    yarnDeps = fetchYarnDeps {
      inherit yarnLock;
      hash = yarnDepsHash;
    };
  };
})
