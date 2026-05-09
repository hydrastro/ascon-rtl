# Repository split

The project should not be one giant NEORV32-specific repository. The reusable
cryptographic core and each platform integration have different constraints.

## Recommended repositories

### `ascon-rtl-core`

Owns only the bus-independent Verilog core:

```text
rtl/
sim/
tools/
doc/
```

Rules:

- no NEORV32 package imports
- no Tiny Tapeout package imports
- no AXI-specific assumptions inside the cryptographic primitive
- all external data packing rules documented at module boundaries

### `ascon-neorv32-accel`

Owns the NEORV32 integration:

```text
rtl/wrappers/neorv32_cfs/
rtl/wrappers/neorv32_xbus/
rtl/wrappers/neorv32_slink/
sw/neorv32-driver/
benchmarks/
```

Goal:

```text
control/status path: CFS or XBUS registers
data path:           DMA/stream/FIFO path, not CPU-polling-only MMIO
```

### `ascon-tt-wrapper`

Owns the Tiny Tapeout wrapper:

```text
src/project.v
src/tt_um_*.v
info.yaml
test/
```

Goal:

- reuse `ascon-rtl-core` modules
- expose a tiny, shuttle-friendly interface
- avoid dragging NEORV32-specific logic into Tiny Tapeout

### Optional `ascon-verify`

Useful only if verification becomes large:

```text
cocotb/
formal/
kat/
```

For now, keep verification inside `ascon-rtl-core` until it becomes heavy enough
to justify a fourth repository.
