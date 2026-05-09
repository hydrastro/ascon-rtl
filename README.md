# ascon-rtl-core

Bus-agnostic Verilog RTL core for an ASCON accelerator.

This repository is intentionally only the reusable cryptographic core. NEORV32,
AXI, and Tiny Tapeout integration should live in separate wrapper repositories.

## Phase status

<<<<<<< HEAD
Implemented in Phase 0/1:
=======
Implemented so far:
>>>>>>> update

- reproducible Nix flake development shell
- upstream `ascon/ascon-c` source wired as the declared golden reference
- one-round combinational ASCON primitive
- parameterized p[12]/p[8]/p[6] permutation controller
- self-checking Icarus Verilog testbench for `ROUNDS_PER_CYCLE = 1, 2, 4, 8`
<<<<<<< HEAD

Not implemented yet:

- AEAD mode
- padding and partial blocks
- tag generation or tag verification
=======
- Phase 2.1 AEAD128 encryption skeleton: no AD, whole 16-byte message blocks only
- Phase 2.1 tag generation for the supported subset

Not implemented yet:

- partial plaintext/ciphertext blocks
- associated data
- decryption and tag verification
>>>>>>> update
- NEORV32 CFS/XBUS/SLINK wrappers
- AXI wrappers
- Tiny Tapeout wrapper

## NixOS usage

```sh
nix develop
make vectors-ascon-c
<<<<<<< HEAD
make sim-iverilog
=======
make sim
>>>>>>> update
```

The flake exports `ASCON_C_DIR` to the checked-out `ascon/ascon-c` source in the
Nix store. The vector generator compiles against that source.

Without Nix:

```sh
git clone https://github.com/ascon/ascon-c external/ascon-c
make vectors-ascon-c ASCON_C_DIR=external/ascon-c
<<<<<<< HEAD
make sim-iverilog
=======
make sim
>>>>>>> update
```

A Python fallback exists for quick local work:

```sh
make vectors-python
```

but the preferred reference path is `make vectors-ascon-c`.

## RTL modules

```text
rtl/ascon_round_comb.v
rtl/ascon_perm_unrolled.v
<<<<<<< HEAD
=======
rtl/ascon_aead128_fullblock_enc.v
>>>>>>> update
```

## State packing convention

```text
state[319:256] = S0
state[255:192] = S1
state[191:128] = S2
state[127:64]  = S3
state[63:0]    = S4
```

This is a word-level convention for the internal permutation. Byte-string
<<<<<<< HEAD
parsing, padding, and little-endian external data handling belong in the AEAD
layer, not in the raw permutation primitive.
=======
parsing and little-endian external data handling belong in wrappers or mode
adapters. The Phase 2.1 AEAD core consumes internal Ascon words directly.
>>>>>>> update

## Throughput model for the later AEAD core

For long Ascon-AEAD128 messages, each full 128-bit message block requires one
p[8] permutation after absorption/encryption.

```text
ideal_bulk_bits_per_cycle = 128 / ceil(8 / ROUNDS_PER_CYCLE)
```

| ROUNDS_PER_CYCLE | p[8] cycles | Ideal bulk rate |
|---:|---:|---:|
| 1 | 8 | 16 bit/cycle |
| 2 | 4 | 32 bit/cycle |
| 4 | 2 | 64 bit/cycle |
| 8 | 1 | 128 bit/cycle |

The system will only reach those rates if the wrapper can feed and drain data at
the same rate. A CPU-fed MMIO interface will not be the final performance path.
