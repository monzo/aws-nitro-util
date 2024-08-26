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
rustPlatform.buildRustPackage {
  name = "eif_build";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
  src = fetchFromGitHub {
    owner = "aws";
    repo = "aws-nitro-enclaves-image-format";
    rev = "v0.3.0";
    hash = "sha256-vtMmyAcNUWzZqS1NQISMdq1JZ9nxOmqSNahnbRhFmpQ=";
  };
  buildAndTestSubdir = "eif_build";
  postPatch = ''
    # symlink our own cargo lock file into build because AWS' source does not include one
    ln -s ${./Cargo.lock} Cargo.lock
  '';
  cargoLock.lockFile = ./Cargo.lock;
}
