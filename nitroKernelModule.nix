{ fetchFromGitHub
, stdenv
, kernel
, flags ? []
, ...
}:
stdenv.mkDerivation rec {
  name = "nsm-driver-${version}-${kernel.version}.ko";
  version = "ac43d10";

  src = fetchFromGitHub {
    owner = "aws";
    repo = "aws-nitro-enclaves-sdk-bootstrap";
    rev = version;
    sha256 = "sha256-z6/2SGD9TR/HMTGsfUY4Uw/as3dNtvPfQl9A2ZGqXnc=";
  };

  # see https://nixos.wiki/wiki/Linux_kernel
  hardeningDisable = [ "pic" "format" ];
  nativeBuildInputs = kernel.moduleBuildDependencies; # 2

  makeFlags = flags ++ [
    "KERNELRELEASE=${kernel.modDirVersion}"
    # "ARCH="
    # "CROSS_COMPILE="
    "-C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" # 4
  ];


  buildPhase = ''
    # TODO - cross compile
    make $makeFlags M=$PWD/nsm-driver
  '';

  installPhase = ''
    cp ./nsm-driver/nsm.ko $out
  '';
}
  