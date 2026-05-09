# NEORV32 software bring-up driver

This directory contains a small polling driver for the 32-bit Ascon-AEAD128
MMIO/XBUS wrapper.

The driver is intentionally dependency-free. It only performs volatile 32-bit
loads/stores, so it can be used from a bare-metal NEORV32 application, a unit
simulation harness, or a board-support package.

## Hardware assumption

The hardware instance at `base` must expose the register map implemented by
`rtl/ascon_aead128_mmio32.v` or the XBUS wrapper
`rtl/ascon_aead128_xbus.v`.

The RTL currently selects encryption or decryption at synthesis/elaboration time
using the `DECRYPT` parameter. If you instantiate only one accelerator at
`0xF0000000`, use either `ascon_accel_encrypt()` or `ascon_accel_decrypt()`
according to that hardware build. If you instantiate two accelerators, give them
different base addresses and call the matching function for each base.

## Byte-order contract

The public software API uses normal byte arrays:

- `key[0]` is the first key byte passed to Ascon-AEAD128.
- `nonce[0]` is the first nonce byte.
- `ad[0]` is the first associated-data byte.
- `plaintext[0]` / `ciphertext[0]` are the first payload bytes.
- `tag[0]` is the first authentication-tag byte.

The driver converts this into the internal register layout used by the RTL.
Do not pre-swap words in application code.

## Authentication contract

Decryption emits plaintext before the final tag verdict is available. The driver
returns `ASCON_ACCEL_ERR_AUTH` when authentication fails. Callers must treat the
plaintext buffer as tentative until `ascon_accel_decrypt()` returns
`ASCON_ACCEL_OK`.
