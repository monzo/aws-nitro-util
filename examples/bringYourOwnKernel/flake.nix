{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/73de017ef2d18a04ac4bfd0c02650007ccb31c2a";

    nitro-util.url = "github:monzo/aws-nitro-util";
    nitro-util.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { nitro-util, nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.aarch64-linux;
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

        closure = pkgs.runCommandNoCC "closure" {} ''
          # mkdir $out
          ${pkgs.nix}/bin/nix-store --query --references ${myScript} $out; 
        '';

        tmp = pkgs.buildEnv {
          name = "tmp";
          buildInputs = [ myScript];
          paths = [ myScript ];
        };



        eif = {
          
         };

      };
    };
}