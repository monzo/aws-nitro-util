# Test-only signing material

> **Warning:** These files are public. Use them only for tests. Do not use them to sign real EIFs.
> Do not trust this certificate in KMS key policies or attestation checks.

- `test-key.pem`: P-384 (secp384r1) EC private key.
- `test-cert.pem`: self-signed certificate for `test-key.pem`. It is valid for 100 years.

The flake uses these files to make `packages.<system>.signing-test-vectors`. The key and certificate do
not change, so PCR8 of the signed test EIF does not change. Thus signers that are made outside this repo
can compare their output with the output of AWS' `eif_build`.
