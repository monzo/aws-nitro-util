{ buildEnv
, writeShellScriptBin
, busybox
, nitro # when you call this function pass `nitro-util.lib.${system}` here
, stdenv
, glibc
, fetchFromGitHub
}:
let
  myScript = writeShellScriptBin "hello" ''
    # note busybox can be used for building EIFs but only on Linux
    # so remove this line if you are building an EIF on MacOS
    export PATH="$PATH:${busybox}/bin"

    while true;
    do
      echo "hello there!";
      sleep 3;
    done
  '';
  arch = stdenv.hostPlatform.uname.processor;
in
nitro.buildEif {
  kernel = nitro.blobs.${arch}.kernel;
  kernelConfig = nitro.blobs.${arch}.kernelConfig;

  name = "eif-hello-world";

  nsmKo = nitro.blobs.aarch64.nsmKo;

  copyToRoot = buildEnv {
    name = "image-root";
    paths = [ myScript ];
    pathsToLink = [ "/bin" ];
  };

  # This example uses AWS' init.c from
  # https://github.com/aws/aws-nitro-enclaves-sdk-bootstrap/tree/main/init
  init = stdenv.mkDerivation {
    name = "eif-init";
    src = (fetchFromGitHub {
      owner = "aws";
      repo = "aws-nitro-enclaves-sdk-bootstrap";
      rev = "746ec5d";
      sha256 = "sha256-KtO/pNYI5uvXrVYZszES6Z0ShkDgORulMxBWWoiA+tg=";
    }) + "/init"; # we just need the subfolder of this repo

    nativeBuildInputs = [ glibc.static ];
    buildPhase = "make";
    installPhase = "cp -r ./init $out";
  };


  entrypoint = "/bin/hello";
  env = "";
}
