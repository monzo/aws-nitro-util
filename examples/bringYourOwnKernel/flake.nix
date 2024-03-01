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
    in
    {

      packages.aarch64-linux = rec {

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

        tmp = pkgs.buildEnv {
          name = "tmp";
          buildInputs = [ myScript ];
          paths = [ myScript ];
        };

        kernel = pkgs.linux;


        eif = nitro.mkEif {
          # use AWS' nitro-cli kernel and kernelConfig
          # inherit (nitro.blobs) kernel kernelConfig;
          kernel = pkgs.linux + "/Image";
          kernelConfig = pkgs.linux.configfile;

          name = "eif-hello-world";
          ramdisks = nitro.mkRamdisksFrom {
              # use AWS' nitro kernel module
              nsmKo = nitroPkgs.nitroKernelModule;
              # set rootfs to your package's path
              rootfs = nixpkgs.legacyPackages.${system}.hello;
              entrypoint = "/bin/hello";
              env = "";
            };
        };
      };
    };
}
