{ lib
, linux_6_8
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
  # use kernel 6.8 with virtio and vsocks
  kernel = linux_6_8.override {
    structuredExtraConfig = with lib.kernel; {
      VIRTIO_MMIO = yes;
      VIRTIO_MENU = yes;
      VIRTIO_MMIO_CMDLINE_DEVICES = yes;
      NET = yes;
      VSOCKETS = yes;
      VIRTIO_VSOCKETS = yes;
    };
    ignoreConfigErrors = true;
  };
in
nitro.buildEif {
  kernel = kernel + (if arch == "aarch64" then "/Image" else "/bzImage");
  kernelConfig = kernel.configfile;

  name = "eif-hello-world";

  # do not include a nsm.ko kernel module, as it is
  # already present in Kernel 6.8+
  nsmKo = null;

  copyToRoot = buildEnv {
    name = "image-root";
    paths = [ myScript ];
    pathsToLink = [ "/bin" ];
  };

  entrypoint = "/bin/hello";
  env = "";
}
