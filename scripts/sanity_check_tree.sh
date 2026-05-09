#!/usr/bin/env bash
set -euo pipefail

bad_files=$(find . \( -name '*.rej' -o -name '*.orig' \) -print)
if [ -n "$bad_files" ]; then
  echo "ERROR: found stale patch files:"
  echo "$bad_files"
  exit 1
fi

for f in \
  rtl/ascon_round_comb.v \
  rtl/ascon_perm_unrolled.v \
  rtl/ascon_aead128_fullblock_enc.v \
  rtl/ascon_aead128_enc.v \
  sim/tb/tb_ascon_perm_unrolled.v \
  sim/tb/tb_ascon_aead128_fullblock_enc.v \
  sim/tb/tb_ascon_aead128_enc.v \
  tools/ascon_c_perm_vectors.c \
  tools/ascon_c_aead128_fullblock_vectors.c \
  tools/ascon_c_aead128_vectors.c \
  Makefile flake.nix; do
  test -f "$f" || { echo "ERROR: missing $f"; exit 1; }
done

grep -q '#define LOCAL_ASCON_128A_RATE 16' tools/ascon_c_aead128_fullblock_vectors.c || {
  echo "ERROR: missing LOCAL_ASCON_128A_RATE define in fullblock vector generator"; exit 1;
}

grep -Fq "full_blocks_left_q <= {4'd0, msg_bytes_i[31:4]};" rtl/ascon_aead128_enc.v || {
  echo "ERROR: width-expansion fix not present in rtl/ascon_aead128_enc.v"; exit 1;
}

echo "Sanity check passed: clean Phase 2.2 tree."
