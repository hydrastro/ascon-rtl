# Phase 4.2 - NEORV32 XBUS Wrapper

This phase adds `ascon_aead128_xbus`, a thin NEORV32 XBUS/Wishbone-style wrapper around the generic `ascon_aead128_mmio32` register interface.

The purpose of this layer is integration, not cryptography.  The verified datapath remains:

```text
ascon_aead128_mmio32
  -> ascon_block_packer32 / ascon_block_unpacker32
  -> ascon_aead128_buffered
  -> encrypt/decrypt AD-capable AEAD core
```

The XBUS wrapper adds:

```text
xbus address decode
xbus cyc/stb/we/sel handshake
one outstanding MMIO transfer
ack/error generation
interrupt passthrough
```

## Address window

The wrapper selects a transfer when:

```verilog
(xbus_adr_i & ADDR_MASK) == BASE_ADDR
```

The low 8 address bits are forwarded to the existing MMIO32 register map.  Therefore the Ascon register file occupies 256 bytes inside the selected XBUS window.

Default parameters:

```verilog
BASE_ADDR = 32'hF000_0000
ADDR_MASK = 32'hFFFF_FF00
```

## Why XBUS now?

The generic MMIO32 wrapper is useful for simulation and software contract validation.  XBUS is the next integration step for NEORV32 because it exposes a real memory-mapped peripheral interface with address/data/strobe/ack semantics, and NEORV32 documents XBUS as the path for processor-external modules and custom accelerators.

This still is not the final maximum-throughput path.  CPU-driven 32-bit stores/loads are useful for bring-up, but sustained throughput eventually needs DMA or a stream path that can feed 128-bit blocks with minimal CPU involvement.

## Test coverage

`tb_ascon_aead128_xbus` reuses the same Ascon-C-generated AEAD AD vectors as the MMIO32 testbench.  It verifies encryption and decryption through XBUS transactions for RPC 1/2/4/8.
