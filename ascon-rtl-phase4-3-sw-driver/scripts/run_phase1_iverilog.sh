#!/usr/bin/env bash
set -euo pipefail
make vectors-ascon-c
make sim-iverilog
