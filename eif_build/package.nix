{ lib
, rustPlatform
, fetchFromGitHub
, openssl
, pkg-config
, ...
}:
#  Enclave image format builder
#  Builds an eif file
#
#  USAGE:
#      eif_build [OPTIONS] --kernel <FILE> --cmdline <String> --output <FILE> --ramdisk <FILE>
#
#  To sign the eif, also give:
#      --signing-certificate <FILE> --private-key <FILE or KMS key ARN>
rustPlatform.buildRustPackage {
  name = "eif_build";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
  src = fetchFromGitHub {
    owner = "aws";
    repo = "aws-nitro-enclaves-image-format";
    rev = "v0.8.1";
    hash = "sha256-6Rb/5Q/75jYO2Cag9S/kNbnOEj6HVmVDjp/WPP5iYx4=";
  };
  buildAndTestSubdir = "eif_build";
  postPatch = ''
    # symlink our own cargo lock file into build because AWS' source does not include one
    ln -s ${./Cargo.lock} Cargo.lock
  '';
  cargoLock.lockFile = ./Cargo.lock;
}
