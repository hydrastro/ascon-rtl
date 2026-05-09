# Phase 3.3 — Buffered decryption stream shell

Phase 3.3 adds the throughput-oriented wrapper around the verified
Ascon-AEAD128 decryption core with associated-data support.

The new module is:

```text
rtl/ascon_aead128_dec_ad_buffered.v
```

It instantiates the Phase 2.4 decryption/authentication core and adds three
ready/valid FIFOs:

```text
AD input FIFO           128-bit blocks
ciphertext input FIFO   128-bit blocks
plaintext output FIFO   128-bit block + 5-bit valid-byte count
```

The authentication verdict remains directly connected to the core because there
is only one verdict per job.

## Authentication contract

The wrapper is still a high-throughput streaming decryptor. It can emit
plaintext before the final tag verdict is available. Downstream software or a
platform wrapper must treat all plaintext as tentative until:

```text
auth_out_valid_o && auth_out_ok_o
```

has been accepted. If the accepted verdict has `auth_out_ok_o == 0`, all
plaintext associated with that job must be discarded.

A later software-facing wrapper may add a safer store-and-release mode by
holding plaintext in memory or an output FIFO until authentication succeeds. This
Phase 3.3 wrapper intentionally does not do that, because it would either reduce
streaming throughput or require job-sized buffering.

## Interface contract

`start_i` is accepted only when `start_ready_o` is high. Input streams may be
preloaded before `start_i`; this models DMA or bus-side FIFO filling. The output
plaintext FIFO must be empty before a new job is accepted so plaintext from two
jobs cannot be interleaved.

`clear_i` clears only the stream FIFOs. Assert it only while the cryptographic
core is idle. Full job abort semantics belong in the later NEORV32/XBUS/SLINK/AXI
control wrapper.

All block fields use the internal Ascon word-packing convention already used by
Phase 2. Raw CPU byte packing is intentionally outside this reusable RTL core.

## Test

Run:

```sh
make sim-aead-buf-dec-iverilog
```

The testbench preloads AD/ciphertext blocks, starts the job, applies plaintext
and authentication backpressure, checks plaintext, valid-byte counts, FIFO empty
state, and verifies both valid and tampered tag cases across RPC 1/2/4/8.

## Next step

Phase 3.4 should introduce a unified job/result shell that selects between the
buffered encryption and buffered decryption datapaths without permanently
doubling the critical path. After that, the platform-specific wrappers can be
added in separate repositories or directories.
