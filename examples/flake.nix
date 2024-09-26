{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nitro-util.url = "github:monzo/aws-nitro-util";
    nitro-util.inputs.nixpkgs.follows = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { nitro-util, nixpkgs, flake-utils, ... }: (flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      nitro = nitro-util.lib.${system};
    in
    {
      packages = {
        # the EIFs below will be for your machine's architecture
        shellScriptEif = pkgs.callPackage ./withShellScript.nix {
          inherit nitro;
        };


        yourOwnInitEif = pkgs.callPackage ./withYourInit.nix {
          inherit nitro;
        };

        yourOwnKernelEif = pkgs.callPackage ./bringYourOwnKernel.nix {
          inherit nitro;
        };

        # the EIFs below will be for the architecture in the package name,
        # even if you build from a different machine
        x86_64-linux-crossCompiledEif =
          let
            crossArch = "x86_64";
            crossPkgs = import nixpkgs { inherit system; crossSystem = "${crossArch}-linux"; };
          in
          crossPkgs.callPackage ./withCrossCompilation.nix {
            inherit crossArch nitro;
          };

        aarch64-linux-crossCompiledEif =
          let
            crossArch = "aarch64";
            crossPkgs = import nixpkgs { inherit system; crossSystem = "${crossArch}-linux"; };
          in
          crossPkgs.callPackage ./withCrossCompilation.nix {
            inherit crossArch nitro;
          };
      };
    }));
}
