### Nix flake for building nitro CLI utilities
{
  description = "Builds AWS Nitro Enclave Image Format files (EIFs) deterministically, cross-platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    nixpkgs.lib.recursiveUpdate
      (flake-utils.lib.eachDefaultSystem
        (system:
          let
            # crates.io 403s curl's user-agent on their API download endpoint.
            # Replace the old URL with the static CDN if present; no-op on newer nixpkgs that already have the fix.
            # See https://github.com/rust-lang/crates.io/issues/13482
            patchedNixpkgsSrc = nixpkgs.legacyPackages.${system}.runCommand "nixpkgs-patched" {} ''
              cp -r ${nixpkgs} $out
              chmod -R u+w $out
              substituteInPlace $out/pkgs/build-support/rust/import-cargo-lock.nix \
                --replace-quiet '"https://crates.io/api/v1/crates"' '"https://static.crates.io/crates"'
            '';
            pkgs = import patchedNixpkgsSrc { inherit system; };
            # returns 'aarch64' from 'aarch64-linux'
            sysPrefix = pkgs.stdenv.hostPlatform.uname.processor;

            defaultCmdline = "reboot=k panic=30 pci=off nomodules console=ttyS0 random.trust_cpu=on root=/dev/ram0";

            /*
             * Returns shell commands that run eif_build (which must be in PATH).
             * The commands write image.eif and log.txt to the current directory.
             * Use extraArgs to give more eif_build arguments, for example to sign the image.
             */
            eifBuildCommand =
              { name, version, ramdisks, kernel, kernelConfig, cmdline, arch, extraArgs ? "" }:
              let
                ramdisksArgs = pkgs.lib.concatStrings (map (ramdisk: "--ramdisk ${ramdisk} ") ramdisks);
                metadataArgs = "--build-tool='monzo-aws-nitro-util' --build-time='1970-01-01T00:00:00.000000+00:00'";
              in
              ''
                eif_build \
                  --arch ${arch} \
                  --kernel ${kernel} \
                  --kernel_config ${kernelConfig} \
                  --cmdline "${cmdline}" \
                  ${ramdisksArgs} \
                  --name ${name} \
                  --version ${version} \
                  ${metadataArgs} \
                  ${extraArgs} \
                  --output image.eif >> log.txt;
              '';

            # Returns a shell command that writes the PCR JSON in an eif_build log to stdout.
            # The JSON has PCR8 only if the image is signed, thus we do not use a fixed number of lines.
            pcrJsonFromLog = log: "sed -n '/^{/,/^}/p' ${log}";

            # Inputs of the simple (non-bootable) x86_64 EIF that the checks and test vectors use
            testEifArgs = with self.lib.${system}; {
              arch = "x86_64";
              name = "test";
              version = "0.1-dev";
              cmdline = defaultCmdline;
              ramdisks = [
                (mkSysRamdisk { init = blobs.x86_64.init; nsmKo = blobs.x86_64.nsmKo; })
                (mkUserRamdisk { entrypoint = "none"; env = ""; rootfs = pkgs.writeTextDir "etc/file" "hello world!"; })
              ];
              kernel = blobs.x86_64.kernel;
              kernelConfig = blobs.x86_64.kernelConfig;
            };
          in
          rec {
            lib = {
              # paths to each of the blobs, for use if you are not compiling these from source
              blobs =
                let
                  blobsFor = kName: prefix: rec {
                    blobPath = self.packages.${system}.aws-nitro-cli-src + "/blobs/${prefix}";

                    /*
                      The kernel binary as pre-compiled by AWS
                    */
                    kernel = blobPath + "/${kName}";
                    kernelConfig = blobPath + "/${kName}.config";
                    cmdLine = blobPath + "/cmdline";

                    /* 
                      nitro kernel module as pre-compiled by AWS
                    */
                    nsmKo = blobPath + "/nsm.ko";

                    /* 
                      init.c program (to boot up the enclave) as pre-compiled by AWS

                      Note you can use `packages.<system>.eif-init` instead,
                      and avoid using a downloaded binary blob.
                    */
                    init = blobPath + "/init";
                  };
                in
                {
                  aarch64 = blobsFor "Image" "aarch64";
                  x86_64 = blobsFor "bzImage" "x86_64";
                };

              /*
                Makes sys and user ramdisks. See mkSysRamdisk and mkUserRamdisk
              */
              mkRamdisksFrom =
                { init ? self.packages.${system}.eif-init
                , nsmKo      # string - path the nitro kernel module
                , entrypoint # string - command to execute after encave boot - this is the path to your entrypoint binary inside rootfs)
                , env        # string - environment variables to pass to the entrypoint)
                , rootfs     # path   - the root filesystem
                }: [
                  (lib.mkSysRamdisk { inherit init nsmKo; })
                  (lib.mkUserRamdisk { inherit entrypoint env rootfs; })
                ];

              /**
               * Assembles an initramfs archive from a compiled init binary and a compiled Nitro kernel module.
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
                , init ? self.packages.${system}.eif-init # path (derivation)
                , nsmKo ? null                                   # path (derivation)
                }:
                lib.mkCpioArchive {
                  inherit name;
                  src = pkgs.runCommand "${name}-fs" { } ''
                    mkdir -p  $out/dev
                    ${if nsmKo == null then "" else "cp ${nsmKo} $out/nsm.ko"}
                    cp ${init} $out/init
                  '';
                };

              /**
               * Assembles an initramfs archive from a root filesystem and config for the entrypoint.
               * The expected layout depends on the source of init.c, but see
               * https://github.com/aws/aws-nitro-enclaves-cli/blob/main/enclave_build/src/yaml_generator.rs
               * for the expected file layout of AWS' init.c
               * 
               * Returns a derivation to a cpio.gz archive
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
               * Uses eif_build to build an image. See packages.eif_build. Note that only Linux EIFs can be made.
               * 
               * Returns a derivation containing:
               *  - image in derivation/image.eif
               *  - PCRs in derivation/pcr.json 
               */
              mkEif =
                { name ? "image-linux-${arch}-${version}-eif"
                , version ? "0.1-dev"
                , ramdisks           # list[path] of ramdisks to use for boot. See mkUserRamdisk and mkSysRamdisk
                , kernel             # path (derivation) to compiled kernel binary
                , kernelConfig       # path (derivation) to kernel config file
                , cmdline ? defaultCmdline # string
                , arch ? sysPrefix   # string - <"aarch64" | "x86_64"> architecture to build EIF for. Defaults to current system's.
                }: pkgs.stdenv.mkDerivation {
                  inherit name version;

                  buildInputs = [ packages.eif_build pkgs.jq ];
                  unpackPhase = ":"; # nothing to unpack

                  buildPhase = ''
                    echo "Kernel:            ${kernel}"
                    echo "Kernel config:      ${kernelConfig}"
                    echo "cmdline:           ${cmdline}"
                    echo "ramdisks:          ${pkgs.lib.concatStrings ramdisks}"
                    ${eifBuildCommand { inherit name version ramdisks kernel kernelConfig cmdline arch; }}
                  '';

                  installPhase = ''
                    mkdir -p $out
                    cp image.eif $out
                    # save logs
                    cp log.txt $out
                    # extract PCRs from logs
                    ${pcrJsonFromLog "log.txt"} > $out/pcr.json
                    # show PCRs in nix build logs
                    jq < $out/pcr.json
                  '';
                };
              inherit pkgs;

              buildEif =
                { name ? "image-linux-${arch}-${version}-eif"
                , version ? "0.1-dev"
                , kernel # path (derivation) to compiled kernel binary
                , kernelConfig       # path (derivation) to kernel config file
                , cmdline ? defaultCmdline # string
                , arch ? sysPrefix   # string - <"aarch64" | "x86_64"> architecture to build EIF for. Defaults to current system's.
                  #  if you change this also set `kernel`
                , copyToRoot         # path - contents that get copied over to the root filesystem
                , copyToRootWithClosure ? true   # bool - whether to also copy copyToRoot's depdencies over
                , entrypoint
                , nsmKo ? null
                , init ? self.crossPackages.${system}."${arch}-linux".eif-init + "/bin/init"
                , env ? ""
                }:
                let
                  # returns a derivation with rootPath and all its dependencies, copied over
                  nixStoreFrom = rootPath: pkgs.runCommandNoCC "pack-closure" { } ''
                    mkdir -p $out/nix/store
                    PATHS=$(cat ${pkgs.closureInfo { rootPaths = [ rootPath ] ; }}/store-paths)
                    for p in $PATHS; do
                      cp -r $p $out/nix/store
                    done
                    cp -r ${rootPath}/* $out
                  '';
                  rootfs = if copyToRootWithClosure then nixStoreFrom copyToRoot else copyToRoot;
                in
                lib.mkEif {
                  inherit kernel kernelConfig cmdline arch name version;

                  ramdisks = [
                    (lib.mkSysRamdisk { inherit init nsmKo; })
                    (lib.mkUserRamdisk { inherit entrypoint env rootfs; })
                  ];
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

            # A CLI to build eif images, provided by AWS in
            # https://github.com/aws/aws-nitro-enclaves-image-format
            packages.eif_build = pkgs.callPackage ./eif_build/package.nix { };

            /*
             * Reference output for EIF signers that are made outside this repo.
             * eif_build signs the test EIF (see checks.test-make-eif) with the public test key in test/signing/.
             *
             * Contains:
             *  - unsigned/{image.eif,pcr.json}     the unsigned test EIF
             *  - signed/{image.eif,pcr.json,log.txt} the same EIF, signed by eif_build
             *  - signing/{test-cert.pem,test-key.pem} the test certificate and key
             *
             * The PCRs do not change between builds. The signed image.eif changes, because ECDSA signatures are randomised.
             */
            packages.signing-test-vectors = pkgs.stdenvNoCC.mkDerivation {
              name = "signing-test-vectors";
              nativeBuildInputs = [ packages.eif_build ];
              dontUnpack = true;

              testCert = ./test/signing/test-cert.pem;
              testKey = ./test/signing/test-key.pem;

              buildPhase = ''
                ${eifBuildCommand (testEifArgs // { extraArgs = "--signing-certificate $testCert --private-key $testKey"; })}
              '';

              installPhase = ''
                mkdir -p $out/unsigned $out/signed $out/signing
                cp ${checks.test-make-eif}/image.eif ${checks.test-make-eif}/pcr.json $out/unsigned/
                cp image.eif log.txt $out/signed/
                ${pcrJsonFromLog "log.txt"} > $out/signed/pcr.json
                cp $testCert $out/signing/test-cert.pem
                cp $testKey $out/signing/test-key.pem
              '';
            };

            /*
             * Takes the system that you would like to compile for,
             * and returns an attribute set with some packages cross-compiled for that system.
             * 
             * Returns normal, non-cross-compiled packages when system == crossSystem.
             * 
             * For example:
             * 
             * `init-for-x86 = (nitro.crossCompile "x86_64-linux").eif-init;`
             * 
             * Note it is currently not possible to compile init.c and the Kernel on darwin.
             */
            crossCompile = crossSystem:
              let crossPkgs = if (system == crossSystem) then pkgs else import nixpkgs { localSystem = system; inherit crossSystem; }; in
              {
                eif-init = crossPkgs.callPackage ./init { };
              };

            crossPackages = {
              x86_64-linux = crossCompile "x86_64-linux";
              aarch64-linux = crossCompile "aarch64-linux";
            };



            checks = {
              # make sure we can build the eif_build CLI
              inherit (packages) eif_build;

              # build a simple (non-bootable) EIF image for x86-64 as part of checks
              test-make-eif = lib.mkEif testEifArgs;

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

              # make sure the signed test EIF can be built
              inherit (packages) signing-test-vectors;

              # check the signed test EIF has the PCRs of the unsigned EIF, plus the PCR8 of the test certificate
              test-signed-eif-PCRs = pkgs.stdenvNoCC.mkDerivation {
                buildInputs = [ pkgs.jq pkgs.openssl ];
                name = "test-signed-eif-PCRs";
                src = packages.signing-test-vectors;
                dontBuild = true;
                doCheck = true;
                checkPhase = ''
                  PCR8=$(jq -r < ./signed/pcr.json ' .PCR8 ')
                  if [ "$PCR8" = "null" ]
                  then
                    echo "signed EIF has no PCR8, eif_build did not sign it"
                    exit 1
                  fi

                  for PCR in PCR0 PCR1 PCR2
                  do
                    SIGNED=$(jq -r < ./signed/pcr.json ".$PCR")
                    UNSIGNED=$(jq -r < ./unsigned/pcr.json ".$PCR")
                    if [ "$SIGNED" != "$UNSIGNED" ]
                    then
                      echo "$PCR of signed EIF ($SIGNED) is not equal to $PCR of unsigned EIF ($UNSIGNED)"
                      exit 1
                    fi
                  done

                  # PCR8 = sha384(48 zero bytes || sha384(DER-encoded signing certificate))
                  EXPECTED_PCR8=$( \
                    { head -c 48 /dev/zero; openssl x509 -in ./signing/test-cert.pem -outform DER | openssl dgst -sha384 -binary; } \
                    | openssl dgst -sha384 -r | cut -d ' ' -f 1)
                  if [ "$PCR8" != "$EXPECTED_PCR8" ]
                  then
                    echo "PCR8 ($PCR8) is not equal to the PCR8 calculated from the test certificate ($EXPECTED_PCR8)"
                    exit 1
                  fi

                  if [ "$PCR8" != "dc0e47401d6d3cc3e3a24ee97772379611fdd9fc0181113866617a753248e1e2b70ab82e71cbfe8cd0b06cf287374073" ]
                  then
                    echo "PCR8 did not match, got instead:" $PCR8
                    exit 1
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

          /*
             * init.c, compiled and statically linked from https://github.com/aws/aws-nitro-enclaves-sdk-bootstrap
             */
          packages.eif-init = self.crossPackages.${system}.${system}.eif-init;

          checks = {
            # make sure we can build init.c
            inherit (packages) eif-init;
          };
        }
      ))
  ;
}
