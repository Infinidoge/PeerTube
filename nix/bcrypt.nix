{ fetchurl
, stdenv
}:
let
  bcryptHostPlatformAttrs = {
    x86_64-linux = {
      arch = "linux-x64";
      libc = "glibc";
      hash = "sha256-C5N6VgFtXPLLjZt0ZdRTX095njRIT+12ONuUaBBj7fQ=";
    };
    aarch64-linux = {
      arch = "linux-arm64";
      libc = "glibc";
      hash = "sha256-TerDujO+IkSRnHYlSbAKSP9IS7AT7XnQJsZ8D8pCoGc=";
    };
    x86_64-darwin = {
      arch = "darwin-x64";
      libc = "unknown";
      hash = "sha256-gphOONWujbeCCr6dkmMRJP94Dhp1Jvp2yt+g7n1HTv0=";
    };
    aarch64-darwin = {
      arch = "darwin-arm64";
      libc = "unknown";
      hash = "sha256-JMnELVUxoU1C57Tzue3Sg6OfDFAjfCnzgDit0BWzmlo=";
    };
  };
  bcryptAttrs = bcryptHostPlatformAttrs."${stdenv.hostPlatform.system}" or
    (throw "Unsupported architecture: ${stdenv.hostPlatform.system}");
  bcryptVersion = "5.1.1";
in
(fetchurl {
  url = "https://github.com/kelektiv/node.bcrypt.js/releases/download/v${bcryptVersion}/bcrypt_lib-v${bcryptVersion}-napi-v3-${bcryptAttrs.arch}-${bcryptAttrs.libc}.tar.gz";
  inherit (bcryptAttrs) hash;
}) // {
  version = bcryptVersion;
}
