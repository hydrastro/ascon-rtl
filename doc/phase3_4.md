# Phase 3.4 — Unified Buffered AEAD Boundary

Phase 3.4 introduces `rtl/ascon_aead128_buffered.v`, a thin job-level shell
that gives platform wrappers one stable stream interface for both encryption and
decryption.

The wrapper deliberately selects the datapath at elaboration time with the
`DECRYPT` parameter:

- `DECRYPT=0`: instantiate only the buffered encryption datapath.
- `DECRYPT=1`: instantiate only the buffered decryption datapath.

This avoids the area penalty of a runtime encrypt/decrypt mux that would require
both engines to exist in hardware.  Future NEORV32, XBUS, SLINK, AXI, and Tiny
Tapeout wrappers should target this boundary rather than the lower-level Phase 2
cores.

## Interface convention

`data_in_*` and `data_out_*` are interpreted according to `DECRYPT`:

| Parameter | `data_in_*` | `data_out_*` | `result_*` |
|---:|---|---|---|
| `DECRYPT=0` | plaintext | ciphertext | generated tag, `result_auth_ok_o=1` |
| `DECRYPT=1` | ciphertext | tentative plaintext | authentication verdict |

The decryption contract remains unchanged: plaintext is tentative until the
result handshake completes with `result_auth_ok_o=1`.

The wrapper keeps the internal 128-bit Ascon block order.  CPU-visible byte
packing remains a platform-wrapper responsibility.

## New targets

```sh
make sim-aead-buffered-iverilog
make synth-aead-buffered-yosys
```

The simulation target checks both `DECRYPT=0` and `DECRYPT=1` for
`ROUNDS_PER_CYCLE=1,2,4,8`.
