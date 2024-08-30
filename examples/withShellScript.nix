{ buildEnv
, writeShellScriptBin
, busybox
, nitro # when you call this function pass `nitro-util.lib.${system}` here
, stdenv
}:
let
  myScript = writeShellScriptBin "hello" ''
    export PATH="$PATH:${busybox}/bin"

    while true;
    do
      echo "hello there $1 !";
      sleep 3;
    done
  '';
  arch = stdenv.hostPlatform.uname.processor;
in
nitro.buildEif {
  inherit arch;
  kernel = nitro.blobs.${arch}.kernel;
  kernelConfig = nitro.blobs.${arch}.kernelConfig;

  name = "eif-hello-world";

  nsmKo = nitro.blobs.aarch64.nsmKo;

  copyToRoot = buildEnv {
    name = "image-root";
    paths = [ myScript ];
    pathsToLink = [ "/bin" ];
  };

  entrypoint = ''
    /bin/hello
    there
  '';

  env = "";
}
