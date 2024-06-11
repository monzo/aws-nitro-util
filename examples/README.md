# Usage examples

Examples are structured as a single flake containing packages of potential EIFs.

To see the overall plumbing to use the aws-nitro-util flake, see [flake.nix](./flake.nix).

To see examples for specific EIFs, see the individual package definitions:

- Booting an enclave with a shell script only: [`withShellScript.nix`](./withShellScript.nix)
- Booting an enclave with your own, compiled-from-source kernel: [`bringYourOwnKernel.nix`](./bringYourOwnKernel.nix)