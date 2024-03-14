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
          while true;
          do
            echo "hello!";
            sleep 3;
          done
        '';

        closure = pkgs.runCommandNoCC "closure" { } ''
          # mkdir $out
          ${pkgs.nix}/bin/nix-store --query --references ${myScript} $out; 
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
          ramdisks = nitro.mkRamdisksFrom {
            nsmKo = null;
            rootfs = nixpkgs.legacyPackages.${system}.hello;
            entrypoint = "/bin/hello";
            env = "";
            cmdline = "reboot=k panic=30 pci=off nomodules console=ttyS0 random.trust_cpu=on root=/dev/ram0";
          };
        };

        eif-rc = nitro.mkEif {
          # use AWS' nitro-cli kernel and kernelConfig
          # inherit (nitro.blobs) kernel kernelConfig;
          kernel = kernel + "/Image";
          kernelConfig = kernel.configfile;

          name = "eif-hello-world";
          ramdisks = nitro.mkRamdisksFrom {
            nsmKo = nitroPkgs.nitroKernelModule.override {
              kernel = kernel;
            };
            rootfs = nixpkgs.legacyPackages.${system}.hello;
            entrypoint = "/bin/hello";
            env = "";
          };
        };

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


            rootfs = nixpkgs.legacyPackages.${system}.hello;
            entrypoint = "/bin/hello";
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
