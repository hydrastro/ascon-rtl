# ascon-c reference usage

The upstream reference is:

```text
https://github.com/ascon/ascon-c
```

In this repository, the preferred vector path is:

```sh
make vectors-ascon-c
```

This compiles `tools/ascon_c_perm_vectors.c` against the upstream source and
writes:

```text
sim/generated/ascon_perm_vectors.vh
```

The C harness includes:

```text
ascon.h
permutations.h
```

and uses the `opt64` round headers for a direct word-level permutation check.
The internal RTL state packing is chosen to match `ascon_state_t.x[0..4]` as:

```text
{ x[0], x[1], x[2], x[3], x[4] }
```

This is intentionally not the same as byte-stream parsing. Byte-stream parsing
is handled later by the AEAD layer.
