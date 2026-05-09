# Phase 4.1 — Generic 32-bit MMIO wrapper

This phase adds `rtl/ascon_aead128_mmio32.v`, a platform-neutral 32-bit
register wrapper around the unified buffered Ascon-AEAD128 datapath.

The goal is not peak throughput yet.  The goal is a stable software-visible
bring-up contract that can later be adapted to NEORV32 CFS/XBUS, AXI-Lite, or a
small Tiny Tapeout control shell.

## Structure

```text
32-bit register bus
  |
  +-- configuration registers: key, nonce, lengths, expected tag
  +-- AD input word port
  +-- payload input word port
  +-- payload output word port
  +-- result/tag/status registers
        |
        v
  32-bit packers/unpacker
        |
        v
  ascon_aead128_buffered
```

The wrapper is parameterized with:

```verilog
parameter integer DECRYPT          = 0;
parameter integer ROUNDS_PER_CYCLE = 1;
```

`DECRYPT=0` synthesizes the encryption datapath.  `DECRYPT=1` synthesizes the
decryption datapath.  This keeps area honest: the generic MMIO wrapper does not
instantiate both encryption and decryption at the same time.

## Address map

Byte addresses:

| Address | Name | Access | Description |
|---:|---|---|---|
| `0x00` | `CTRL` | W | bit0 start, bit1 clear, bit2 result_ack |
| `0x04` | `STATUS` | R | ready/busy/done/output/result/FIFO status |
| `0x08` | `AD_BYTES` | R/W | associated-data length in bytes |
| `0x0c` | `MSG_BYTES` | R/W | payload length in bytes |
| `0x10..0x1c` | `KEY0..KEY3` | R/W | 128-bit key, word0 at `[31:0]` |
| `0x20..0x2c` | `NONCE0..NONCE3` | R/W | 128-bit nonce, word0 at `[31:0]` |
| `0x30..0x3c` | `TAG0..TAG3` | R/W | expected decrypt tag |
| `0x40` | `AD_IN` | W | 32-bit associated-data stream |
| `0x44` | `DATA_IN` | W | 32-bit plaintext/ciphertext stream |
| `0x48` | `DATA_OUT` | R | 32-bit ciphertext/plaintext stream; read pops |
| `0x4c` | `DOUT_META` | R | bits `[2:0]` bytes, bit8 last, bit16 valid |
| `0x50..0x5c` | `RESULT0..RESULT3` | R | encryption tag; zero for decrypt |
| `0x60` | `LEVELS` | R | FIFO level summary |

## Packing convention

The wrapper uses the same raw internal 32-bit lane order as the Phase 3.5 block
adapters:

```text
word 0 <-> block[31:0]
word 1 <-> block[63:32]
word 2 <-> block[95:64]
word 3 <-> block[127:96]
```

This is not yet a user-friendly byte-string API.  The software driver or a later
platform-specific wrapper must convert byte arrays to this internal lane order.

## Result contract

Encryption:

* `STATUS[4]` indicates a pending result.
* `STATUS[5]` is always one for a completed encryption job.
* `RESULT0..RESULT3` contain the generated tag.

Decryption:

* plaintext output is tentative until `STATUS[4] && STATUS[5]`.
* if `STATUS[4] && !STATUS[5]`, software must discard the plaintext from that
  job.

`CTRL.result_ack` clears the pending result and interrupt.

## Tests

Run:

```sh
make sim-mmio32-iverilog
```

This tests both elaboration modes (`DECRYPT=0` and `DECRYPT=1`) for
`ROUNDS_PER_CYCLE = 1, 2, 4, 8` against the `ascon-c`-derived AEAD+AD vectors.
