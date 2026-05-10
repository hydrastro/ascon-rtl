# Phase 5.3 — AXI-Lite + AXI4-Stream AEAD wrapper

This phase adds `ascon_aead128_axi`, the first complete AXI-facing wrapper.

## Architecture

```text
AXI-Lite control/status
        |
        v
ascon_aead128_axi
        |
        +-- AXI4-Stream AD input
        +-- AXI4-Stream payload input
        +-- AXI4-Stream payload output
```

The wrapper instantiates the Phase 5.2 stream shell `ascon_aead128_axis`.

## Register map

Offsets are byte addresses:

| Offset | Name      | Access | Description |
|---:|---|---|---|
| `0x00` | `CTRL` | W | bit0 start, bit1 clear, bit2 result_ack |
| `0x04` | `STATUS` | R | ready/busy/done/result/auth/fifo/error status |
| `0x08` | `AD_BYTES` | RW | associated-data length |
| `0x0c` | `MSG_BYTES` | RW | payload length |
| `0x10..0x1c` | `KEY` | RW | 128-bit key |
| `0x20..0x2c` | `NONCE` | RW | 128-bit nonce |
| `0x30..0x3c` | `TAG_IN` | RW | expected tag for decrypt |
| `0x50..0x5c` | `RESULT` | R | generated tag for encrypt, zero for decrypt |
| `0x60` | `LEVELS` | R | FIFO levels packed into bytes |

## AXI-Lite behavior

This wrapper implements a compact AXI-Lite slave:

- `AW` and `W` are accepted together.
- `AR` is accepted independently.
- `BRESP` and `RRESP` are always `OKAY`.

This is sufficient for most simple SoC and simulation use, but a later hardening
pass can add independently buffered AW/W channels if required.

## Operation order

Recommended driver order:

1. Write `CTRL.clear`.
2. Write key, nonce, lengths, and optional decrypt tag.
3. Stream AD blocks on `s_axis_ad`.
4. Stream payload blocks on `s_axis_data`.
5. Write `CTRL.start`.
6. Drain `m_axis_data`.
7. Poll `STATUS.result_valid`.
8. Read `RESULT` and `STATUS.auth_ok`.
9. Write `CTRL.result_ack`.

The current core FIFOs are small, so large software/DMA drivers should interleave
input streaming, output draining, and status polling rather than preloading an
unbounded amount of data.

## Next phase

Phase 5.4 should add a driver/simulation harness for the AXI wrapper and a
synthesis matrix, then we can decide whether to implement a DMA memory master or
keep the wrapper as AXI-Lite + AXI4-Stream.
