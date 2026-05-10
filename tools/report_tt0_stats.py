#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Summarize TT-0 Yosys stat reports."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def parse_stat(path: Path) -> dict[str, int | str]:
    text = path.read_text(errors="replace")
    lines = text.splitlines()
    result: dict[str, int | str] = {"file": str(path)}

    for m in re.finditer(r"Number of cells:\s+(\d+)", text):
        result["number_of_cells"] = int(m.group(1))

    interesting = {
        "$_AND_": "and",
        "$_ANDNOT_": "andnot",
        "$_DFF_PN0_": "dff",
        "$_DFFE_PN0P_": "dffe",
        "$_MUX_": "mux",
        "$_NAND_": "nand",
        "$_NOR_": "nor",
        "$_NOT_": "not",
        "$_OR_": "or",
        "$_ORNOT_": "ornot",
        "$_XNOR_": "xnor",
        "$_XOR_": "xor",
    }

    for line in lines:
        parts = line.strip().split()
        if len(parts) == 2 and parts[1] in interesting:
            try:
                result[interesting[parts[1]]] = int(parts[0])
            except ValueError:
                pass

    if "number_of_cells" not in result:
        for m in re.finditer(r"^\s*(\d+)\s+cells\s*$", text, re.MULTILINE):
            result["number_of_cells"] = int(m.group(1))

    return result


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: report_tt0_stats.py build/tt0/*.txt", file=sys.stderr)
        return 2

    rows = [parse_stat(Path(p)) for p in argv[1:]]
    keys = ["file", "number_of_cells", "andnot", "and", "dffe", "dff", "mux", "xor", "xnor"]

    widths = {k: len(k) for k in keys}
    for row in rows:
        for k in keys:
            widths[k] = max(widths[k], len(str(row.get(k, "-"))))

    print("  ".join(k.ljust(widths[k]) for k in keys))
    print("  ".join("-" * widths[k] for k in keys))
    for row in rows:
        print("  ".join(str(row.get(k, "-")).ljust(widths[k]) for k in keys))

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
