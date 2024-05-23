# Security Policy

## Supported Versions

This repo operates on a rolling basis, with the last major version receiving security updates to the building process.

The only part of this repository that actually ends up in the enclave is the init process. Consider using [AWS' init process](https://github.com/aws/aws-nitro-enclaves-sdk-bootstrap) too (which can be compiled from source) if you prefer to rely on their security policy.

## Upstream Packages' vulnerabilities

You are welcome to report vulnerabilities for upstream dependencies' packages, but keep in mind you can update your dependencies yourself without updating `aws-nitro-util` by having it inherit another flake input. See [the documentation](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake#flake-inputs) for details.

## Reporting a Vulnerability

You can responsibly disclose vulnerabilities to `security@monzo.com`. 