#!/usr/bin/env bash
set -euo pipefail

file="rtl/ascon_aead128_mmio32.v"

if [[ ! -f "$file" ]]; then
  echo "ERROR: run this from the ascon-rtl repository root; missing $file" >&2
  exit 1
fi

# Clean stale patch/editor leftovers that intentionally fail the sanity checker.
find . -type f \( -name '*.rej' -o -name '*.orig' \) -print -delete

python3 - <<'PY'
from pathlib import Path
p = Path('rtl/ascon_aead128_mmio32.v')
s = p.read_text()
old = '''  wire write_transfer_w = reg_valid_i && reg_write_i && reg_ready_o;
  wire read_transfer_w  = reg_valid_i && !reg_write_i && reg_ready_o;

  wire ctrl_start_w      = write_transfer_w && is_ctrl_w && reg_wdata_i[0];
  wire ctrl_clear_w      = write_transfer_w && is_ctrl_w && reg_wdata_i[1];
  wire ctrl_result_ack_w = write_transfer_w && is_ctrl_w && reg_wdata_i[2];
'''
new = '''  // CTRL writes are always accepted, while stream ports may apply backpressure.
  // Keep CTRL side effects independent of reg_ready_o to avoid a combinational
  // loop through clear_i -> packer ready -> reg_ready_o -> write_transfer_w.
  wire ctrl_transfer_w  = reg_valid_i && reg_write_i && is_ctrl_w;
  wire write_transfer_w = reg_valid_i && reg_write_i && reg_ready_o;
  wire read_transfer_w  = reg_valid_i && !reg_write_i && reg_ready_o;

  wire ctrl_start_w      = ctrl_transfer_w && reg_wdata_i[0];
  wire ctrl_clear_w      = ctrl_transfer_w && reg_wdata_i[1];
  wire ctrl_result_ack_w = ctrl_transfer_w && reg_wdata_i[2];
'''
if old in s:
    p.write_text(s.replace(old, new, 1))
    print('updated rtl/ascon_aead128_mmio32.v')
elif 'wire ctrl_transfer_w  = reg_valid_i && reg_write_i && is_ctrl_w;' in s:
    print('rtl/ascon_aead128_mmio32.v already has ctrl_transfer_w fix')
else:
    print('ERROR: expected transfer block not found; inspect rtl/ascon_aead128_mmio32.v around write_transfer_w', flush=True)
    raise SystemExit(1)
PY

if grep -n 'ctrl_clear_w[[:space:]]*= write_transfer_w' "$file"; then
  echo "ERROR: old ctrl_clear_w expression is still present" >&2
  exit 1
fi

grep -n 'ctrl_transfer_w\|ctrl_clear_w\|write_transfer_w' "$file"

echo "OK: MMIO CTRL combinational-loop source pattern removed."
