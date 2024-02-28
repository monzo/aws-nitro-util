### Nix flake for building nitro CLI utilities
# 
# This is linux-only, if you are using MacOS
#  - if you have nix-darwin installed (see https://daiderd.com/nix-darwin/manual/index.html#opt-nix.linux-builder.enable )
#    - run nix build .#packages.aarch64-linux.eif-cli
#  - if you don't have Nix but have Docker (see Dockerfile):
#     - docker build --platform=linux/aarch64 -t nix-tmp . && docker run -it -t nix-tmp
#
{
  description = "Builds binaries for key exchange scripts deterministically, cross-platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    nixpkgs.lib.recursiveUpdate
      (flake-utils.lib.eachDefaultSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages."${system}";
            # returns 'aarch64' from 'aarch64-linux'
            sysPrefix = with pkgs.lib.strings;
              if (hasSuffix "-linux" system) then (removeSuffix "-linux" system) else (removeSuffix "-darwin" system);
          in
          rec {
            lib = {
              # paths to each of the blobs, for use if you are not compiling these from source
              blobs =
                let
                  blobsFor = kName: prefix: rec {
                    blobPath = self.packages.${system}.aws-nitro-cli-src + "/blobs/${prefix}";
                    kernel = blobPath + "/${kName}";
                    kernelConfig = blobPath + "/${kName}.config";
                    cmdLine = blobPath + "/cmdline";
                    nsmKo = blobPath + "/nsm.ko";
                    init = blobPath + "/init";
                  };
                in
                {
                  aarch64 = blobsFor "Image" "aarch64";
                  x86_64 = blobsFor "bzImage" "x86_64";
                };

              /* Assembles an initramfs archive from a compiled init binary and a compiled Nitro kernel module.
               *
               * The expected layout depends on the source of init.c, but see
               * https://github.com/aws/aws-nitro-enclaves-cli/blob/main/enclave_build/src/yaml_generator.rs
               * for the expected file layout of AWS' init.c
               *
               * By default, init is a compiled-from-source version of AWS' default init.c. See packages.init
               *
               * Returns a derivation to a cpio.gz archive
               */
              mkSysRamdisk =
                { name ? "bootstrap-initramfs"
                , init ? packages.eif-init    # path (derivation)
                , nsmKo                       # path (derivation)
                }:
                lib.mkCpioArchive {
                  inherit name;
                  src = pkgs.runCommand "${name}-fs" { } ''
                    mkdir -p  $out/dev
                    cp ${nsmKo} $out
                    cp ${init} $out
                  '';
                };

              /* Assembles an initramfs archive from a root filesystem and config for the entrypoint.

            The expected layout depends on the source of init.c, but see
            https://github.com/aws/aws-nitro-enclaves-cli/blob/main/enclave_build/src/yaml_generator.rs
            for the expected file layout of AWS' init.c

            Returns a derivation to a cpio.gz archive
              */
              mkUserRamdisk =
                { name ? "user-initramfs"
                , entrypoint # string - command to execute after encave boot - this is the path to your entrypoint binary inside rootfs)
                , env        # string - environment variables to pass to the entrypoint)
                , rootfs     # path   - the root filesystem
                }: lib.mkCpioArchive {
                  inherit name;
                  src = pkgs.runCommand "${name}-fs" { } ''
                    mkdir -p  $out/rootfs
                    cp ${pkgs.writeText "${name}-env" env} $out/env
                    cp ${pkgs.writeText "${name}-entrypoint" entrypoint} $out/cmd
                    cp -r ${rootfs}/* $out/rootfs

                    (cd $out/rootfs && mkdir -p dev run sys var proc tmp || true)
                  '';
                };

              /* deterministically builds a cpio archive that can be used as an initramfs iamge */
              mkCpioArchive =
                { name ? "archive"
                , src # path (derivation) of unarchived folder
                }: pkgs.runCommand "${name}.cpio.gz"
                  {
                    inherit src;
                    buildInputs = [ pkgs.cpio ];
                  }
                  ''
                    mkdir -p root
                    cp -r $src/* root/

                    find root -exec touch -h --date=@1 {} +
                    (cd root && find * .[^.*] -print0 | sort -z | cpio -o -H newc -R +0:+0 --reproducible --null | gzip -n > $out)
                  '';


              /*
               * Uses eif-cli to build an image. See packages.eif-cli. Note that only Linux EIFs can be made.
               * 
               * Returns a derivation containing:
               *  - image in derivation/image.eif
               *  - PCRs in derivation/pcr.json 
               */
              mkEif =
                { name ? "image"
                , version ? "0.1-dev"
                , ramdisks           # list[path] of ramdisks to use for boot. See mkUserRamdisk and mkSysRamdisk
                , kernel             # path (derivation) to compiled kernel binary
                , kernelConfig       # path (derivation) to kernel config file
                , cmdline ? "reboot=k panic=30 pci=off nomodules console=ttyS0 random.trust_cpu=on root=/dev/ram0" # string
                , arch ? sysPrefix   # string - <"aarch64" | "x86_64"> architecture to build EIF for. Defaults to current system's.
                }: pkgs.stdenv.mkDerivation {
                  pname = "${name}.eif";
                  inherit version;

                  buildInputs = [ packages.eif-cli pkgs.jq ];
                  unpackPhase = ":"; # nothing to unpack 
                  buildPhase =
                    let
                      ramdisksArgs = with pkgs.lib; concatStrings (map (ramdisk: "--ramdisk ${ramdisk} ") ramdisks);
                    in
                    ''
                      eif=${packages.eif-cli}/bin/eif-cli

                      echo "Kernel:            ${kernel}"
                      echo "Kernel config:     ${kernelConfig}"
                      echo "cmdline:           ${cmdline}"
                      echo "ramdisks:          ${pkgs.lib.concatStrings ramdisks}"
                      $eif --sha384 --arch ${arch} --kernel ${kernel} --kernel_config ${kernelConfig} --cmdline "${cmdline}" ${ramdisksArgs} --name ${name} --version ${version} --output image.eif >> log.txt
                    '';

                  installPhase = ''
                    mkdir -p $out
                    cp image.eif $out
                    # save logs
                    cp log.txt $out
                    # extract PCRs from logs
                    cat log.txt | tail -1 >> $out/pcr.json
                    # show PCRs in nix build logs
                    jq < $out/pcr.json
                  '';
                };


              # returns a derivation that is folder containing a deterministic filesystem of the image's layers
              unpackImage =
                { name ? "image-rootfs"
                , imageName
                , imageDigest
                , sha256
                , arch ? pkgs.go.GOARCH # default architecture for current nixpkgs
                }:
                pkgs.runCommand name
                  {
                    inherit imageDigest name;
                    sourceURL = "docker://${imageName}@${imageDigest}";
                    impureEnvVars = pkgs.lib.fetchers.proxyImpureEnvVars;
                    outputHashMode = "recursive";
                    outputHashAlgo = "sha256";
                    outputHash = sha256;

                    buildInputs = [ pkgs.skopeo pkgs.umoci ];
                    SSL_CERT_FILE = "${pkgs.cacert.out}/etc/ssl/certs/ca-bundle.crt";

                    destNameTag = "private.io/pulled:latest";
                  } ''
                  skopeo \
                    --insecure-policy \
                    --tmpdir=$TMPDIR \
                    --override-os linux \
                    --override-arch ${arch} \
                    copy \
                    "$sourceURL" "oci:image:latest" \
                    | cat  # pipe through cat to force-disable progress bar

                  mkdir -p $out
                  umoci raw unpack  --rootless --image image $out
                  echo "Unpacked filesystem:"
                  ls -la $out
                '';
            };

            # The repo we get compiled blobs from
            packages.aws-nitro-cli-src =
              let
                hashes = rec {
                  x86_64-linux = "sha256-+vQ9XK3la7K35p4VI3Mct5ij2o21zEYeqndI7RjTyiQ=";
                  aarch64-darwin = "sha256-GeguCHNIOhPYc9vUzHrQQdc9lK/fru0yYthL2UumA/Q=";
                  aarch64-linux = x86_64-linux;
                  x86_64-darwin = aarch64-darwin;
                };
              in
              pkgs.fetchFromGitHub {
                owner = "aws";
                repo = "aws-nitro-enclaves-cli";
                rev = "v1.2.3";
                sha256 = hashes.${system};
              };

            # A CLI to build eif images, a thin wrapper around AWS' library
            # https://github.com/aws/aws-nitro-enclaves-image-format
            # eif-cli [OPTIONS] --kernel <FILE> --kernel_config <FILE> --cmdline <String> --output <FILE> --ramdisk <FILE>
            packages.eif-cli = pkgs.rustPlatform.buildRustPackage rec {
              name = "eif-cli";
              nativeBuildInputs = [ pkgs.pkg-config ];
              buildInputs = [ pkgs.openssl ];
              src = ./eif-cli;
              cargoLock.lockFile = src + "/Cargo.lock";
            };

            checks = {
              # make sure we can build the eif-cli
              inherit (packages) eif-cli;

              # build a simple (non-bootable) EIF image for ARM64 as part of checks
              test-make-eif = lib.mkEif {
                arch = "x86_64";
                name = "test";
                ramdisks = [
                  (lib.mkSysRamdisk { init = lib.blobs.x86_64.init; nsmKo = lib.blobs.x86_64.nsmKo; })
                  (lib.mkUserRamdisk { entrypoint = "none"; env = ""; rootfs = pkgs.writeTextDir "etc/file" "hello world!"; })
                ];
                kernel = lib.blobs.x86_64.kernel;
                kernelConfig = lib.blobs.x86_64.kernelConfig;
              };

              # check the PCR for this simple EIF is reproduced
              test-eif-PCRs-match = pkgs.stdenvNoCC.mkDerivation {
                buildInputs = [ pkgs.jq ];
                name = "test-eif-PCRs-match";
                src = checks.test-make-eif;
                dontBuild = true;
                doCheck = true;
                checkPhase = ''
                  PCR0=$(jq -r < ./pcr.json ' .PCR0 ')
                  if echo "$PCR0" | grep -qv 'f585cae40c5d5d640a60d3c7f8c5dcf7276364c49f7d7fa8d08800b35c45825099688c2acc02bb2373ebfbd8a5ba10b4'
                  then
                    echo "PCR0 did not match, got instead:" $PCR0
                    exit -1
                  fi
                '';
                installPhase = "mkdir $out";
              };
            };
          }
        ))

      # we are not cross-compiling init.c, which needs gcc:
      (flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
        let
          pkgs = nixpkgs.legacyPackages."${system}";
        in
        rec {
          # init.c, compiled and statically linked from https://github.com/aws/aws-nitro-enclaves-sdk-bootstrap
          packages.eif-init = pkgs.stdenv.mkDerivation {
            name = "eif-init";
            src = (pkgs.fetchFromGitHub {
              owner = "aws";
              repo = "aws-nitro-enclaves-sdk-bootstrap";
              rev = "746ec5d";
              sha256 = "sha256-KtO/pNYI5uvXrVYZszES6Z0ShkDgORulMxBWWoiA+tg=";
            }) + "/init"; # we just need the subfolder of this repo

            nativeBuildInputs = [ pkgs.glibc.static ];
            buildPhase = "make";
            installPhase = "mkdir -p $out && cp -r ./init $out/";
          };

          checks = {
            # make sure we can build init.c
            inherit (packages) eif-init;
          };
        }
      ))
  ;
}
