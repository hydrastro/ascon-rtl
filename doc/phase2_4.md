# Phase 2.4: AEAD128 decryption with associated data

This phase adds the first decryption core:

```text
rtl/ascon_aead128_dec_ad.v
```

Scope:

```text
- Ascon-AEAD128 decryption
- arbitrary associated-data length
- arbitrary ciphertext/plaintext length
- tag verification
- RPC = 1, 2, 4, 8
```

The decryption core mirrors the Phase 2.3 encryption core:

```text
initialization -> AD absorption -> ciphertext processing -> finalization -> tag compare
```

## Authentication contract

The current design is optimized for a streaming accelerator. It emits plaintext blocks before the final authentication verdict is available.

The user of the core must treat plaintext as tentative until:

```text
auth_valid_o && auth_ok_o
```

If `auth_valid_o && !auth_ok_o`, all plaintext emitted for that job must be discarded.

A future wrapper can implement a safer store-and-release policy by buffering plaintext until authentication succeeds, but that is not suitable for the maximum-throughput core itself unless external memory/DMA buffering is part of the design.

## New testbench

```text
sim/tb/tb_ascon_aead128_dec_ad.v
```

The decryption testbench reuses the Phase 2.3 `ascon-c` generated encryption vectors:

```text
sim/generated/ascon_aead128_ad_vectors.vh
```

It verifies:

```text
- plaintext recovery for all AD/message length cases
- byte-valid reporting on partial final plaintext blocks
- successful tag authentication
- one tampered-tag rejection case
```

## New targets

```sh
make sim-aead-dec-ad-iverilog
make synth-aead-dec-ad-yosys
```

The normal full regression also includes decryption now:

```sh
make sim
make lint-verilator
```
