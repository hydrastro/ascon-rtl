# Phase 4.3: NEORV32 software bring-up driver

Phase 4.3 adds a small C driver for the generic 32-bit MMIO/XBUS wrapper.

The purpose of this phase is not peak throughput. The purpose is to make the
accelerator software-visible in a controlled and reproducible way before adding
DMA/streaming integration.

## Added files

- `sw/neorv32/ascon_accel.h`
- `sw/neorv32/ascon_accel.c`
- `sw/neorv32/ascon_accel_demo.c`
- `sw/neorv32/README.md`

## Register interface

The driver targets the register map from `rtl/ascon_aead128_mmio32.v` and works
through either the generic register bus or the `ascon_aead128_xbus` wrapper.

The driver performs:

1. clear/reset job state;
2. write key, nonce, tag-in for decrypt;
3. write AD and message byte lengths;
4. stream AD words;
5. stream plaintext/ciphertext words;
6. start the job;
7. read output words;
8. wait for result/authentication;
9. acknowledge the result.

## Byte ordering

The C API accepts ordinary byte arrays. Internally, the driver performs the same
mapping as the 32-bit block adapters:

- stream word 0 carries bytes 0..3 of a 16-byte Ascon rate block;
- stream word 1 carries bytes 4..7;
- stream word 2 carries bytes 8..11;
- stream word 3 carries bytes 12..15.

KEY/NONCE/TAG registers expose the raw internal 128-bit layout, so the driver
also handles that conversion. Application code should not pre-swap key, nonce,
tag, AD, or payload bytes.

## Authentication contract

The decryption datapath is streaming. Plaintext can be emitted before the final
tag comparison is known. Software must treat decrypted bytes as tentative until
`ascon_accel_decrypt()` returns `ASCON_ACCEL_OK`.

## Next phase

Phase 4.4 should add a self-checking NEORV32 simulation or board application
that links this driver and compares accelerator output against `ascon-c` test
vectors.
