{ buildEnv
, writeShellScriptBin
, busybox
, nitro # when you call this function pass `nitro-util.lib.${system}` here
, stdenv
}:
let
  myScript = writeShellScriptBin "hello" ''

    while true;
    do
      echo "hello there!";
      sleep 3;
    done
  '';
  arch = "x86_64";
in
nitro.buildEif {
  inherit arch;
  kernel = nitro.blobs.${arch}.kernel;
  kernelConfig = nitro.blobs.${arch}.kernelConfig;
  init = nitro.blobs.${arch}.init;


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
