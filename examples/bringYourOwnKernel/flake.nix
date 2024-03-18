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

      nixStoreFrom = { rootPaths }: pkgs.runCommandNoCC "pack-closure" {}''
        mkdir -p $out/nix/store
        PATHS=$(cat ${pkgs.closureInfo { inherit rootPaths; }}/store-paths)
        for p in $PATHS; do
          cp -r $p $out/nix/store
        done
      '';
    in
    {

      packages.${system} = rec {

        myScript = pkgs.writeShellScriptBin "hello" ''
          export PATH="$PATH:${pkgs.busybox}/bin"
          while true;
          do
            echo "hello!";
            sleep 3;
            lsmod
          done
        '';

        # tmp = pkgs.buildEnv {
        #   name = "tmp";
        #   buildInputs = [ myScript ];
        #   paths = [ myScript ];
        # };

        # kernel = pkgs.linux;


        eif = nitro.mkEif {
          # use AWS' nitro-cli kernel and kernelConfig
          # inherit (nitro.blobs) kernel kernelConfig;
          kernel = kernel + "/Image";
          kernelConfig = kernel.configfile;

          name = "eif-hello-world";

          cmdline = "reboot=k panic=30 pci=off nomodules console=ttyS0 random.trust_cpu=on root=/dev/ram0";
          ramdisks = nitro.mkRamdisksFrom {
            nsmKo = null;
            rootfs = nixStoreFrom { rootPaths = [ myScript ]; };
            entrypoint = "${myScript}/bin/hello";
            env = "";
          };
        };

        # eif-rc = nitro.mkEif {
        #   # use AWS' nitro-cli kernel and kernelConfig
        #   # inherit (nitro.blobs) kernel kernelConfig;
        #   kernel = kernel + "/Image";
        #   kernelConfig = kernel.configfile;

        #   name = "eif-hello-world";
        #   ramdisks = nitro.mkRamdisksFrom {
        #     nsmKo = nitroPkgs.nitroKernelModule.override {
        #       kernel = kernel;
        #     };
        #     rootfs = nixpkgs.legacyPackages.${system}.hello;
        #     entrypoint = "/bin/hello";
        #     env = "";
        #   };
        # };



        eif2 = nitro.mkEif {
          kernel = nitro.blobs.aarch64.kernel;
          kernelConfig = nitro.blobs.aarch64.kernelConfig;
          # kernel = kernel + "/Image";
          # kernelConfig = kernel.configfile;

          name = "eif-hello-world";
          ramdisks = nitro.mkRamdisksFrom {
            # init = nitro.blobs.aarch64.init;
            init = nitroPkgs.eif-init;


            nsmKo = nitro.blobs.aarch64.nsmKo;
            # nsmKo = nitroPkgs.nitroKernelModule.override {
            #   inherit kernel;
            # };


            rootfs = nixStoreFrom { rootPaths = [ myScript ]; };
            entrypoint = "${myScript}/bin/hello";
            env = "";
          };
        };

        tmp = pkgs.stdenv;
        # debugUsrInit = nitro.mkUserRamdisk {
        #   rootfs = nixpkgs.legacyPackages.${system}.hello;
        #   entrypoint = "/bin/hello";
        #   env = "";
        # };

        # debugSysInit = nitro.mkSysRamdisk {
        #   nsmKo = nitroPkgs.nitroKernelModule;
        # };
      };
    };
}
