{ buildEnv
, hello
, nitro # when you call this function pass `nitro-util.lib.${system}` here
, crossArch
}:
nitro.buildEif {
  arch = crossArch;
  kernel = nitro.blobs.${crossArch}.kernel;
  kernelConfig = nitro.blobs.${crossArch}.kernelConfig;

  name = "eif-hello-world";

  nsmKo = nitro.blobs.${crossArch}.nsmKo;

  copyToRoot = buildEnv {
    name = "image-root";
    # the image passed here must be a Nix derivation that can be cross-compiled
    # we did not use a shell script here because that is hard for GNU coreutils
    paths = [ hello ];
    pathsToLink = [ "/bin" ];
  };

  entrypoint = ''
    /bin/hello
  '';

  env = "";
}
