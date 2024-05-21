{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

    nitro-util.url = "github:monzo/aws-nitro-util/nico.add-override-copyToRoot";
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

        bringYourOwnKernelEif = pkgs.callPackage ./bringYourOwnKernel.nix {
          inherit nitro;
        };
      };
    }));
}
