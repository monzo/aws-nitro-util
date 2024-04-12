{ buildEnv
, writeShellScriptBin
, busybox
, nitro # this should be nitro-util.lib.${system}
, stdenv
}:
let
  myScript = writeShellScriptBin "hello" ''
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

  entrypoint = "/bin/hello";
  env = "";
}
