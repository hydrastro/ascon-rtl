# Phase 3.1: Stream FIFO layer

Phase 2 completed the algorithm-level AEAD datapath:

- encryption with associated data
- decryption with associated data
- arbitrary AD/message byte lengths
- tag generation and verification
- `ROUNDS_PER_CYCLE = 1, 2, 4, 8`

Phase 3 starts the throughput-oriented accelerator shell. The first block is a reusable single-clock ready/valid FIFO.

## Why this matters

The Ascon core can theoretically consume or produce one 128-bit block per p[8] permutation. At `ROUNDS_PER_CYCLE=8`, the bulk datapath can complete a full 128-bit payload block per cycle after initialization/finalization overhead. A CPU-driven MMIO interface cannot sustain that rate. The final NEORV32 accelerator therefore needs buffering between the bus/DMA side and the AEAD core.

## Added RTL

```text
rtl/ascon_stream_fifo.v
```

The FIFO is generic:

```verilog
ascon_stream_fifo #(
  .WIDTH(134),
  .DEPTH_LOG2(2)
)
```

A 134-bit block is enough for the current stream payload convention:

```text
bit 132      : last/metadata flag, wrapper-defined
bits 132:128 : byte count or sideband, wrapper-defined
bits 127:0   : Ascon block data
```

The FIFO itself does not interpret those bits.

## Interface contract

```text
in_valid_i  && in_ready_o   -> enqueue one word
out_valid_o && out_ready_i  -> dequeue one word
```

The FIFO supports simultaneous enqueue and dequeue. When full, `in_ready_o` is still asserted if the output side is also accepting a word in the same cycle. That preserves one-word-per-cycle throughput during steady-state operation.

## Added test

```text
sim/tb/tb_ascon_stream_fifo.v
```

It checks:

- ordered delivery under source gaps
- ordered delivery under sink stalls
- simultaneous push/pop behavior
- level never exceeds depth
- clear from non-empty state

## Targets

```sh
make sim-fifo-iverilog
```

The full simulation target now includes the FIFO test.

## Next phase

Phase 3.2 should instantiate these FIFOs around the AEAD core and define the job-level streaming interface:

```text
control/job descriptor: key, nonce, op, ad_bytes, msg_bytes, tag
input streams:         AD blocks and payload blocks
output streams:        payload blocks and tag/auth status
```

That wrapper becomes the stable boundary for NEORV32 CFS/XBUS/SLINK and Tiny Tapeout wrappers.
