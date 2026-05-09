# Phase 3.5: 32-bit block adapters

This phase adds platform-neutral 32-bit word adapters around the internal
128-bit Ascon block stream.

The cryptographic cores remain bus-agnostic.  These adapters are intended for
future memory-mapped wrappers such as NEORV32 CFS/XBUS debug paths, simple
simulation harnesses, and low-pin-count wrappers.  They are not the final
maximum-throughput data path; the high-throughput path remains the 128-bit
ready/valid stream used by `ascon_aead128_buffered`.

## Lane order

Both adapters use 32-bit byte-stream order for the internal Ascon block layout:

```text
word 0 <-> block[95:64]   (bytes 0..3)
word 1 <-> block[127:96]  (bytes 4..7)
word 2 <-> block[31:0]    (bytes 8..11)
word 3 <-> block[63:32]   (bytes 12..15)
```

This is a bit-vector packing convention only.  It does not change the Ascon
word/byte conventions inside the cryptographic core.

## `ascon_block_packer32`

The packer accepts 32-bit words with ready/valid and emits 128-bit blocks.

A block is emitted when either:

- four 32-bit words have been accepted, or
- `word_last_i` is accepted before the fourth word.

`word_bytes_i` must be 1, 2, 3, or 4 when `word_valid_i` is high.  For partial
words, valid bytes are the low-order bytes of `word_data_i`; unused upper bytes
are zeroed before insertion into the block.

## `ascon_block_unpacker32`

The unpacker accepts a 128-bit block and a byte count, then emits the valid
32-bit lanes.  It marks the final emitted word with `word_last_o` and reports
that word's valid byte count through `word_bytes_o`.

A block with `block_bytes_i == 0` is accepted and dropped without producing any
output words.

## Throughput role

These adapters make the next wrapper step much simpler, but they are still a
32-bit boundary.  The performance target for the accelerator remains:

```text
128-bit stream/FIFO interface -> Ascon core -> 128-bit stream/FIFO interface
```

A 32-bit MMIO wrapper is useful for bring-up and software control.  It should
not be presented as the maximum-throughput datapath.
