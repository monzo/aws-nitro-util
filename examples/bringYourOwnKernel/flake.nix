{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/73de017ef2d18a04ac4bfd0c02650007ccb31c2a";

    nitro-util.url = "github:monzo/aws-nitro-util/kernel";
    nitro-util.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { nitro-util, nixpkgs, ... }:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      nitro = nitro-util.lib.${system};
      nitroPkgs = nitro-util.packages.${system};
      kernel_68_rc7 = pkgs.linux.override {
        argsOverride = {
          src = pkgs.fetchurl {
            url = "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-6.8-rc7.tar.gz";
            sha256 = "sha256-ff+VhfWcCXlDRKfikAaxcLdrRb+YgM8BHPPgoVwfB2g=";
          };
          version = "6.8-rc7";
          modDirVersion = "6.8-rc7";
        };
      };
      kernel_68_rc6 = pkgs.linux.override {
        argsOverride = {
          src = pkgs.fetchurl {
            url = "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-6.8-rc6.tar.gz";
            sha256 = "sha256-GhuvgL4gfMB6ONL8NI48WWJJAPBYT+6vFS8OwGkKz74=";
          };
          version = "6.8.0-rc6";
          modDirVersion = "6.8.0-rc6";
        };
      };
      kernel =  kernel_68_rc6;
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
            nsmKo = nitroPkgs.nitroKernelModule;
            rootfs = nixpkgs.legacyPackages.${system}.hello;
            entrypoint = "/bin/hello";
            env = "";
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
