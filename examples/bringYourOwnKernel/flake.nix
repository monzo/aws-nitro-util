{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nitro-util.url = "github:monzo/aws-nitro-util/kernel";
    nitro-util.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { nitro-util, nixpkgs, ... }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      nitro = nitro-util.lib.${system};
      nitroPkgs = nitro-util.packages.${system};

      kernel = pkgs.linux_6_8;
      # pkgs.linux;
    in
    {

      packages.${system} = rec {

        myScript = pkgs.writeShellScriptBin "hello" ''
          export PATH="$PATH:${pkgs.busybox}/bin"
          while true;
          do
            echo "hello there!";
            sleep 3;
          done
        '';

        eif = let kernel = pkgs.linux_6_8; in
          nitro.buildEif {
            kernel = kernel + "/Image";
            kernelConfig =
              # kernel.configfile;
              # copy kernel config contents to a new file
              (pkgs.writeTextDir "Image.config" (builtins.readFile kernel.configfile)) + "/Image.config";
            # kernel = nitro.blobs.aarch64.kernel;
            # kernelConfig = nitro.blobs.aarch64.kernelConfig;

            name = "eif-hello-world";

            nsmKo = null;

            # init = nitro.blobs.aarch64.init;
            # init = nitroPkgs.eif-init;
            # init = "${goinit}/bin/init";


            # nsmKo = nitro.blobs.aarch64.nsmKo;
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [ myScript ];
              pathsToLink = [ "/bin" ];
            };
            # cmdline = "reboot=k panic=30 pci=off modules_load=nsm console=ttyS0 random.trust_cpu=on root=/dev/ram0";
            cmdline = "reboot=k panic=30 pci=off nomodules console=ttyS0 random.trust_cpu=on root=/dev/ram0";
            entrypoint = "/bin/hello";
            env = "";
          };


        eif3 = nitro.buildEif {
          kernel = nitro.blobs.aarch64.kernel;
          kernelConfig = nitro.blobs.aarch64.kernelConfig;
          # kernel = kernel + "/Image";
          # kernelConfig = kernel.configfile;

          name = "eif-hello-world";

          # init = nitro.blobs.aarch64.init;
          # init = nitroPkgs.eif-init;
          # init = "${goinit}/bin/init";


          nsmKo =
            null; # also works!
          # nitro.blobs.aarch64.nsmKo;
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [ myScript ];
            pathsToLink = [ "/bin" ];
          };
          entrypoint = "/bin/hello";
          env = "";
        };

        tmp = pkgs.stdenv;
      };
    };
}
