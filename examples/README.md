# Usage examples

You need to install [Nix](https://nixos.org/) and [enable flakes](https://nixos.wiki/wiki/Flakes) to use this repo.
Examples are structured as an additional Nix flake containing [derivations](https://zero-to-nix.com/concepts/derivations) (ie, build recipes, like Dockerfiles) for potential EIFs.

To see the overall plumbing to use the aws-nitro-util flake, see [flake.nix](./flake.nix).

To see examples for specific EIFs, see the individual package definitions:

- Booting an enclave with a shell script only: [`withShellScript.nix`](./withShellScript.nix)
- Booting an enclave with your own, compiled-from-source kernel: [`bringYourOwnKernel.nix`](./bringYourOwnKernel.nix)

## Building the examples

### To show what examples can be built

```bash
nix flake show
```

### To build `shellScriptEif` for your current architecture:
```bash
nix build '.#shellScriptEif'
```
Note this will produce an `aarch64-linux` EIF if you are running it in an ARM Mac.


### To build for a different architecture via a remote builder
Nix allows compiling 'natively' for other architectures by building in a different machine.

To do this you need to set up a [linux remote builder](https://nix.dev/manual/nix/2.18/advanced-topics/distributed-builds) first.
This can be any machine you can SSH into, including a VM.

Then, for example, to compile EIFs natively for `x86_64-linux` on an ARM Mac:
```bash
nix build '.#packages.x86_64-linux.shellScriptEif'
```

Using remote builders makes builds simpler (because it is a linux x86 machine compiling linux x86 binaries) but requires setting
up that additional machine and telling your local Nix installation about it.

### To build for a different architecture via cross-compilation

If you do not have remote builders, you can cross-compile. Keep in mind this requires all dependencies
of your EIF to be cross-compiled too (which is tricky for bash scripts).


To cross-compile an EIF from your local system
to `x86_64-linux`:

```bash
nix build '.#x86_64-linux-shellScriptEif'
```
