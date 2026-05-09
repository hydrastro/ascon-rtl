# Phase 5.1 — AXI4-Stream block adapters

This phase adds the first AXI-facing reusable components to `ascon-rtl`.

## Scope

Implemented:

- `rtl/axi/ascon_axis_ingress128.v`
- `rtl/axi/ascon_axis_egress128.v`
- `sim/tb/tb_ascon_axis_adapters.v`

Not implemented yet:

- AXI-Lite register/control wrapper.
- Full AEAD AXI wrapper.
- DMA engine.
- Burst memory master.

## Rationale

The core AEAD datapath already uses a 128-bit ready/valid block stream internally. AXI4-Stream is the natural high-throughput external equivalent. This phase validates byte ordering, `tkeep`, `tlast`, masking, and backpressure before we connect the adapters to the AEAD job shell.

## Byte order

AXI byte order:

```text
tdata[7:0]       = byte 0
tdata[15:8]      = byte 1
...
tdata[127:120]   = byte 15
```

Internal ASCON block order:

```text
block[127:64] = first 8 bytes loaded little-endian into ASCON word 0
block[63:0]   = next  8 bytes loaded little-endian into ASCON word 1
```

Mapping:

```text
bytes 0..3    <-> block[95:64]
bytes 4..7    <-> block[127:96]
bytes 8..11   <-> block[31:0]
bytes 12..15  <-> block[63:32]
```

This matches the existing `ascon_block_packer32` / `ascon_block_unpacker32` convention.

## `tkeep`

The ingress adapter expects `tkeep` to be contiguous from bit 0 upward. Non-contiguous `tkeep` is flagged via `keep_error_o`.

The egress adapter generates low-contiguous `tkeep` from a byte count.

## Next phase

Phase 5.2 should instantiate these adapters around `ascon_aead128_buffered`:

```text
AXI-Lite registers
      |
      v
ascon_aead128_axis
      |
      +-- AXIS AD input
      +-- AXIS payload input
      +-- AXIS payload output
      +-- result/tag/auth status
```
