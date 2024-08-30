# Usage examples

Examples are structured as a single flake containing packages of potential EIFs.

To see the overall plumbing to use the aws-nitro-util flake, see [flake.nix](./flake.nix).

To see examples for specific EIFs, see the individual package definitions:

- Booting an enclave with a shell script only: [`withShellScript.nix`](./withShellScript.nix)
- Booting an enclave with your own, compiled-from-source kernel: [`bringYourOwnKernel.nix`](./bringYourOwnKernel.nix)

## Building the examples

**To show what examples can be built**

```bash
nix flake show
```

**To compile `shellScriptEif` for your current architecture:**
```bash
nix build .#shellScriptEif
```
Note this will produce an `aarch64-linux` EIF if you are running it in an ARM Mac.

Assuming you have a linux [remote builder](https://nix.dev/manual/nix/2.18/advanced-topics/distributed-builds) available,
**to compile EIFs natively for `x86_64-linux` on an ARM Mac:**

```bash
nix build .#packages.x86_64-linux.shellScriptEif
```

If you do not have remote builders, you can always try to cross-compile. Keep in mind this requires all dependencies
of your EIF to be cross-compiled too (which is tricky for bash scripts). **To cross-compile an EIF from your local system
to `x86_64-linux`:**

```bash
nix build .#x86_64-linux-shellScriptEif
```
