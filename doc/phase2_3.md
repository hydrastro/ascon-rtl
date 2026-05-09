# Phase 2.3: AEAD128 encryption with associated data

Phase 2.3 adds `rtl/ascon_aead128_enc_ad.v`, a bus-agnostic Ascon-AEAD128 encryption core with associated-data support.

## Scope

Implemented:

- encryption only
- arbitrary associated-data byte length
- arbitrary plaintext byte length
- 128-bit internal block stream for AD and plaintext
- 128-bit ciphertext stream with valid-byte count
- tag generation
- `ROUNDS_PER_CYCLE = 1, 2, 4, 8`

Still intentionally out of scope:

- decryption
- authentication failure path
- NEORV32 wrapper
- DMA/FIFO frontend
- CPU byte-order packing

## Interface model

The module consumes AD first, then plaintext, then emits the tag.

```text
start -> initialization -> AD stream -> plaintext stream -> tag
```

The stream widths are internal Ascon word order:

```text
ad_block_i         = {A0, A1}
plaintext_block_i  = {M0, M1}
ciphertext_block_o = {C0, C1}
tag_o              = {T0, T1}
```

The bus wrapper remains responsible for converting raw byte strings into the little-endian 64-bit Ascon words used by the core.

## AD padding rule

AD processing follows the Ascon-AEAD128 rule:

- if `ad_bytes_i == 0`, no AD permutation is performed;
- if `ad_bytes_i != 0`, the AD is padded and followed by `P8`;
- if AD length is an exact multiple of 16 bytes, an extra empty padded AD block is absorbed and followed by `P8`;
- domain separation is applied after AD processing in all cases.

## Test targets

Run:

```sh
make clean
make vectors-ascon-c
make sim-aead-ad-iverilog
make lint-verilator
make synth-aead-ad-yosys
```

Full regression:

```sh
make clean && make vectors-ascon-c && make sim && make lint-verilator
```
