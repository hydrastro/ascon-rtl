# Phase 2: AEAD128 mode layer

Phase 2 builds the Ascon-AEAD128 sequencing logic on top of the verified
permutation core.

## Phase 2.1 scope

The first checked-in mode core is `rtl/ascon_aead128_fullblock_enc.v`.
It intentionally supports a narrow subset:

- encryption only
- no associated data
- messages whose length is exactly `16 * msg_blocks_i` bytes
- final empty-block padding is applied, so zero-block and whole-block messages
  match the NIST/ascon-c AEAD algorithm
- internal 64-bit Ascon word packing only; wrappers will handle raw CPU/bus
  byte order later

This slice is not the final accelerator. It exists to validate the mode FSM:
initialization, domain separation, plaintext absorption, p[8] scheduling,
final empty-block padding, finalization, and tag emission.

## Packing contract

```text
key_i[127:64]           = K0 = LOADBYTES(k,     8)
key_i[63:0]             = K1 = LOADBYTES(k + 8, 8)
nonce_i[127:64]         = N0 = LOADBYTES(n,     8)
nonce_i[63:0]           = N1 = LOADBYTES(n + 8, 8)
plaintext_block_i       = {M0, M1}
ciphertext_block_o      = {C0, C1}
tag_o                   = {T0, T1}
```

The NEORV32, AXI, SLINK, and Tiny Tapeout wrappers must convert raw bytes into
this internal word order. Keeping that conversion outside the crypto core avoids
mixing algorithm logic with bus policy.

## Verification

Vectors are generated from upstream `ascon/ascon-c` through:

```sh
make vectors-ascon-c
```

The Phase 2.1 simulation target is:

```sh
make sim-aead-iverilog
```

The full regression is:

```sh
make clean
make vectors-ascon-c
make sim
make lint-verilator
```

## Next Phase 2 slices

1. Add partial final plaintext blocks and byte-valid masks.
2. Add associated data absorption.
3. Add decryption and constant-time tag comparison.
4. Replace the simple block-count interface with a streaming command interface.
5. Add FIFOs and throughput-oriented backpressure behavior.
