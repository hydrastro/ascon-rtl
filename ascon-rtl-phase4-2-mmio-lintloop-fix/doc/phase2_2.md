# Phase 2.2: AEAD128 encryption with partial plaintext blocks

This phase adds `rtl/ascon_aead128_enc.v`, an encryption-only Ascon-AEAD128 core
with no associated data and arbitrary plaintext length in bytes.

The core remains bus-agnostic. It uses internal Ascon word packing:

```text
key_i[127:64]       = K0 = LOADBYTES(k,     8)
key_i[63:0]         = K1 = LOADBYTES(k + 8, 8)
nonce_i[127:64]     = N0 = LOADBYTES(n,     8)
nonce_i[63:0]       = N1 = LOADBYTES(n + 8, 8)
plaintext_block_i   = {M0, M1}
ciphertext_block_o  = {C0, C1}
tag_o               = {T0, T1}
```

`msg_bytes_i` declares the complete plaintext length. The core requests
`ceil(msg_bytes_i / 16)` plaintext blocks. `ciphertext_bytes_o` reports how
many bytes are valid in each ciphertext block. Empty messages produce no
ciphertext block and one tag.

Run:

```sh
make vectors-ascon-c
make sim-aead-var-iverilog
make lint-verilator
make synth-aead-var-yosys
```

Phase 2.2 does not include associated data or decryption. Those are the next
algorithmic slices.
