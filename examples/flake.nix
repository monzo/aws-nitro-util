{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nitro-util.url = "path:../";
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

        shellScriptEif = pkgs.callPackage ./withShellScript.nix {
          inherit nitro;
        };


        yourOwnInitEif = pkgs.callPackage ./withYourInit.nix {
          inherit nitro;
        };

        yourOwnKernelEif = pkgs.callPackage ./bringYourOwnKernel.nix {
          inherit nitro;
        };

      };
    }));
}
