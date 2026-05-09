# Phase 3.2 — Buffered encryption stream shell

Phase 3.2 introduces the first throughput-oriented wrapper around the verified
Ascon-AEAD128 encryption core with associated-data support.

The new module is:

```text
rtl/ascon_aead128_enc_ad_buffered.v
```

It instantiates the Phase 2.3 encryption core and adds three ready/valid FIFOs:

```text
AD input FIFO          128-bit blocks
plaintext input FIFO   128-bit blocks
ciphertext output FIFO 128-bit block + 5-bit valid-byte count
```

The tag stream remains directly connected to the core because there is only one
128-bit tag per job. A later system-level wrapper may choose to buffer tags or
pack them into a result FIFO together with status bits.

## Interface contract

`start_i` is accepted only when `start_ready_o` is high. Input streams may be
preloaded before `start_i`; this models DMA or bus-side FIFO filling. The output
ciphertext FIFO must be empty before a new job is accepted so ciphertext from two
jobs cannot be interleaved.

`clear_i` clears only the stream FIFOs. It should only be asserted while the
cryptographic core is idle. Full job abort semantics belong in the later
NEORV32/XBUS/SLINK/AXI control wrapper.

All block fields use the internal Ascon word-packing convention already used by
Phase 2. Raw CPU byte packing is still intentionally outside this reusable RTL
core.

## Test

Run:

```sh
make sim-aead-buf-enc-iverilog
```

The testbench preloads AD/plaintext blocks, starts the job, applies ciphertext
and tag backpressure, and checks ciphertext, valid-byte counts, tag, and FIFO
empty state for all generated associated-data vectors across RPC 1/2/4/8.

## Next step

Phase 3.3 should add the symmetric buffered decryption shell around
`ascon_aead128_dec_ad`. After that, the stable boundary for platform wrappers
will be ready:

```text
job descriptor + input block streams + output block/result streams
```
