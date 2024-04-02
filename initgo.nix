{ buildGoModule
, ...
}: buildGoModule {
  name = "eif-init";
  src = ./init;

  CGO_ENABLED = 0;
  ldflags = [ "-s" "-w" ];
  # nativeBuildInputs = [ glibc.static ];
}