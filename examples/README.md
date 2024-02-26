# Nitro util examples


For most cases (where you make an EIF in the same OS and arch you want to run it on) all you need is to tweak the `rootfs` parameter. `rootfs` takes a string/a path to a folder containing your runtime's directory structure.

## EIF from nix package

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nitro-util.url = "github:monzo/aws-nitro-util";
    nitro-util.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, flake-utils, nitro-util, ... }:
    let system = x86_64-linux; 
        nitro = nitro-util.lib.${system};
    in {
        packages.${system}.eif-hello-world = nitro.mkEif {
            # use AWS' nitro-cli kernel and kernelConfig
            inherit (nitro.blobs) kernel kernelConfig;
            name = "eif-hello-world";
            ramdisks = nitro.mkRamdisksFrom {
                # use AWS' nitro kernel module
                inherit (nitro.blobs) nsmKo;
                # set rootfs to your package's path
                rootfs = nixpkgs.legacyPackages.${system}.hello;
                entrypoint = "/bin/hello";
            };
        };
    };
}
```

## EIF from OCI container

The idea is to download the OCI container from your registry and unpack it into a folder, and use that folder as `rootfs`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nitro-util.url = "github:monzo/aws-nitro-util";
    nitro-util.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, flake-utils, nitro-util, ... }:
    let system = x86_64-linux; 
        pkgs = nixpkgs.legacyPackages.${system};
        nitro = nitro-util.lib.${system};
        unpackedImage = unpackImage {
            imageName = "hello-world";
            imageDigest = "sha256:4bd78111b6914a99dbc560e6a20eab57ff6655aea4a80c50b0c5491968cbc2e6";
            # you can put a 'wrong' sha256 here and see it fail in order
            # to trust-on-first-use
            sha256 = "sha256-EAMt8Xt7EAK3GRqMOGYzJRX7Xc49F8SjatcZyoEo/Pk=";
        };
    in {
        packages.${system}.eif-hello-world = nitro.mkEif {
            # use AWS' nitro-cli kernel and kernelConfig
            inherit (nitro.blobs) kernel kernelConfig;
            name = "eif-hello-world";
            ramdisks = nitro.mkRamdisksFrom {
                # use AWS' nitro kernel module
                inherit (nitro.blobs) nsmKo;
                # set rootfs to your image's path
                rootfs = unpackedImage;
                entrypoint = "/hello";
            };
        };
    };
}
```

## EIF from compiled Go binary

This is the same as [doing it from a nix package](#eif-from-nix-package), except
you make the package yourself

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nitro-util.url = "github:monzo/aws-nitro-util";
    nitro-util.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { self, nixpkgs, flake-utils, nitro-util, ... }:
    let system = x86_64-linux; 
        pkgs = nixpkgs.legacyPackages.${system};
        nitro = nitro-util.lib.${system};
    in {
        packages.${system}.my-go-package = pkgs.buildGo121Module {
            version = "0.1";
            vendorHash = "sha256-xxxx";
            pname = "my-go-package";
            src = ./my-go-package;
        };

        packages.${system}.eif-hello-world = nitro.mkEif {
            # use AWS' nitro-cli kernel and kernelConfig
            inherit (nitro.blobs) kernel kernelConfig;
            name = "eif-hello-world";
            ramdisks = nitro.mkRamdisksFrom {
                # use AWS' nitro kernel module
                inherit (nitro.blobs) nsmKo;
                # set rootfs to your package's path
                rootfs = self.packages.${system}.my-go-package;
                entrypoint = "/bin/hello";
            };
        };
    };
}
```