{ stdenv
, fetchFromGitHub
, glibc
}:
stdenv.mkDerivation {
  name = "eif-init";
  src = (fetchFromGitHub {
    owner = "aws";
    repo = "aws-nitro-enclaves-sdk-bootstrap";
    rev = "746ec5d";
    sha256 = "sha256-KtO/pNYI5uvXrVYZszES6Z0ShkDgORulMxBWWoiA+tg=";
  }) + "/init"; # we just need the subfolder of this repo

  nativeBuildInputs = [ glibc.static ];
  buildPhase = "make";
  installPhase = "cp -r ./init $out";
}
