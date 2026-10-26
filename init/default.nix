{ buildGoModule
, ...
}: buildGoModule {
  name = "eif-init";
  src = ./.;

  vendorHash = null;

  env.CGO_ENABLED = 0;
  ldflags = [ "-s" "-w" ];
}