# AWS Nitro utilities

This repo contains a Nix flake with some helpers to reproducibly build AWS Nitro Enclave image files.

You can think of it as an alternative to `nitro-cli build-enclave` for building EIFs. The idea is to:
- have  a more secure EIF-building process, by having the tool that builds them also be bit-by-bit reproducible, thus reducing the surface for supply-chain attacks
- remove the dependency on containers completely, while still allowing their use
- give users complete control over their enclave images, providing additional options like BYOK (Bring Your Own Kernel)
- easily build EIFs on systems other than Amazon Linux, including M1+ Macs (e.g, it's possible to build an x86_64 Linux EIF on an ARM Mac)


The tradeoffs are:
| Feature | `nitro-cli build-enclave` | monzo/aws-nitro-util |
|---------|-----------|----------------------|
| EIF userspace input | Docker container | any filesystem, including nix packages
| EIF bootstrap input | pre-compiled kernel binary provided by AWS | Bring Your Own Kernel (but you can still choose AWS' if you choose not to compile your own kernel)
| dependencies | Docker, linuxkit fork, [aws/aws-nitro-enclaves-image-format](https://github.com/aws/aws-nitro-enclaves-image-format/) | Nix, [aws/aws-nitro-enclaves-image-format](https://github.com/aws/aws-nitro-enclaves-image-format/)
| Source-reproducible | no, uses pre-compiled blobs provided by AWS | yes, can be built entirely from source
| Bit-by-bit reproducible EIFs | no, EIFs are timestamped | yes, building the same EIF will result in the same SHA256
| cross-architecture EIFs | yes, if you provide a container for the right architecture | yes, if you provide binaries for the right architecture
| OS | [Amazon Linux](https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave-cli-install.html) unless you [compile `nitro-cli` from source](https://github.com/aws/aws-nitro-enclaves-cli/tree/main/docs) for other Linux | any Linux or MacOS with a Nix installation
| Build spec | Dockerfile + nitro-cli CLI | Nix build

## Examples


### Building an image from a package

Assuming a self-contained Nix package (like a Go binary):
```nix
```

Assuming an existing container image in a remote registry you want to make into en EIF:
```nix
```

Assuming a local directory with pre-compiled binaries:
```nix
```

## Design

monzo/aws-nitro-util is made up of a small CLI that wraps  [aws/aws-nitro-enclaves-image-format](https://github.com/aws/aws-nitro-enclaves-image-format/) (which allows building an EIF from a specific filesystem) and of Nix utilities to reproducibly build the CLI and its inputs.

```mermaid
%%{init: {"flowchart": {"htmlLabels": false}} }%%

graph TD
	style main stroke:#018E01
	style main stroke-width:4

	style initBin stroke:#018E01
	style initBin stroke-width:4

	style eifCli stroke:#018E01
	style eifCli stroke-width:4


	style nsm stroke:#9B6201
	style nsm stroke-width:4

	style kernel stroke:#9B6201
	style kernel stroke-width:4



	subgraph The internet
		eifFormatRepo("📦 github repo \n aws/ \n aws-nitro-enclaves-\nimage-format")
		nitroCliRepo("📦 github repo \n aws/ \n aws-nitro-enclaves-\n cli")
		bootstrapRepo("📦 github repo \n aws/ \n aws-nitro-enclaves-\nsdk-bootstrap")
		yourRepo("your source code")


	end
	initBin("init \n compiled init.c")
	eifCli("📦 eif-cli \n CLI written \n from source")
	kernel("Kernel \n binary")
	nsm("nsm.ko \n compiled Nitro \n kernel module")
	sysInit("system-initramfs \n (app-agnositc) \n PCR1")
	userInit("user-initramfs \n (app-specific)\n PCR2")
	
	rootfs("rootfs \n folder containing \n filesystem \n (eg, compiled main.go)")

	doEif(("package \n EIF..."))
	doSysInit(("package sys \n initramfs..."))
	doUserInit(("package user \n initramfs..."))
	
	yourRepo -->|compile \n from source|main("main \n compiled \n binary")
	main --> rootfs
	bootstrapRepo -->|compile \nfrom source|initBin

	nitroCliRepo -.->|has under blobs/|nsm
	nitroCliRepo -.->|has under blobs/|kernel

	rootfs --> doUserInit
	doUserInit==> userInit

	initBin --->doSysInit
	nsm-->doSysInit
	doSysInit ==> sysInit

	eifFormatRepo ---> |pulled as \n build-time Rust \n cargo dependency|eifCli
	eifCli -->doEif
	kernel -->doEif
	sysInit ==>doEif
	userInit ==>doEif


	doEif -->eif("image.eif \n enclave image")
	doEif -->pcr("pcr.json \n PCR signatures")
```
