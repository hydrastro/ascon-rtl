# TT-0 — Tiny Tapeout feasibility profile

This is not a Tiny Tapeout implementation yet.

The goal of TT-0 is to quantify the smallest useful RTL configurations before
designing a Tiny Tapeout-specific top-level protocol.

## Why this exists

The FPGA/SoC wrappers in this repo are intentionally wide and throughput-driven:

- FIFOs
- 128-bit datapaths
- MMIO
- AXI4-Stream
- AXI-Lite

Those are not appropriate for a very small ASIC shuttle wrapper. Tiny Tapeout
needs a separate top-level wrapper with a tiny pin protocol.

The reusable pieces are lower in the stack:

```text
ascon_round_comb
ascon_perm_unrolled
ascon_aead128_enc
ascon_aead128_enc_ad
ascon_aead128_dec_ad
```

## Profiles

TT-0 adds synthesis targets for:

| Target | Meaning |
|---|---|
| `tt_perm_rpc1` | permutation engine only |
| `tt_enc_rpc1` | encryption, no AD |
| `tt_enc_ad_rpc1` | encryption with AD |
| `tt_dec_ad_rpc1` | decryption with AD and tag check |

All use `ROUNDS_PER_CYCLE=1`, because area is the first constraint for a small
ASIC-style target.

## What is deliberately excluded

The following are excluded from TT-0:

- stream FIFOs
- buffered wrappers
- MMIO wrapper
- AXI wrappers
- NEORV32/XBUS wrappers
- UART/SPI wrappers
- Tiny Tapeout pin protocol

## Interpretation

This phase gives an area sanity check. It does not answer final Tiny Tapeout fit,
because final fit also depends on:

- selected Tiny Tapeout top-level pin protocol
- required I/O registers
- scan/reset requirements
- OpenLane/PDK synthesis and physical results
- whether encryption only is acceptable
- whether associated data and decryption are required

## Recommended decision process

1. Run `make synth-tt0-yosys`.
2. Inspect `build/tt0/*.txt`.
3. Compare relative area:
   - permutation only
   - encryption only
   - encryption + AD
   - decrypt + AD
4. Choose the minimum viable Tiny Tapeout scope.
5. Only then design `ascon-tt`.

Likely Tiny Tapeout first candidate:

```text
encryption-only
no AD or fixed AD policy
RPC=1
small serial 8-bit input/output protocol
no FIFO
```
