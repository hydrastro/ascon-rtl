# Phase 0 / Phase 1 plan

## Phase 0 contract

Acceptance criteria:

- `nix develop` provides the hardware development shell.
- `ascon/ascon-c` is the declared upstream golden reference.
- `make vectors-ascon-c` generates Verilog test vectors from `ascon-c`.
- `make sim-iverilog` runs the permutation testbench.
- The raw permutation has no bus/protocol dependency.
- State packing is documented.

## Phase 1 scope

Implemented modules:

```text
ascon_round_comb
ascon_perm_unrolled
```

`ascon_perm_unrolled` supports:

```text
rounds_i = 12  -> Ascon-p[12]
rounds_i = 8   -> Ascon-p[8]
rounds_i = 6   -> Ascon-p[6], useful as optional coverage
```

and:

```text
ROUNDS_PER_CYCLE = 1, 2, 4, 8
```

## Design rationale

The permutation is the deepest combinational datapath and the throughput limiter.
Verifying it before AEAD mode prevents later padding, endian, tag, or wrapper
bugs from being confused with cryptographic-round bugs.

## Handoff to Phase 2

Next module should be a block-level Ascon-AEAD128 core with a deliberately simple
command interface, still no NEORV32-specific bus logic.

Initial Phase 2 boundary sketch:

```text
key_i[127:0]
nonce_i[127:0]
ad_block_i[127:0]
msg_block_i[127:0]
block_valid_i
block_ready_o
block_last_i
block_bytes_i[4:0]
ct_block_o[127:0]
ct_valid_o
tag_o[127:0]
tag_valid_o
```

Precise byte ordering and partial-block semantics must be locked before writing
that RTL.
