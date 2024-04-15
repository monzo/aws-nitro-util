{ linux_6_8
, buildEnv
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
  kernel = linux_6_8;
in
nitro.buildEif {
  kernel = kernel + (if arch == "aarch64" then "/Image" else "/bzImage");
  kernelConfig = kernel.configfile;

  name = "eif-hello-world";

  nsmKo = null;

  copyToRoot = buildEnv {
    name = "image-root";
    paths = [ myScript ];
    pathsToLink = [ "/bin" ];
  };

  entrypoint = "/bin/hello";
  env = "";
}
