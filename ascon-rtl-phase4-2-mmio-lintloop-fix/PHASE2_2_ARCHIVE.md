# ascon-rtl Phase 2.2 clean archive

This archive is a clean tree. It must not contain `.rej`, `.orig`, or `build/` artifacts.

Recommended first commands:

```sh
./scripts/sanity_check_tree.sh
nix develop
make clean
make vectors-ascon-c && make sim && make lint-verilator
```

Important: use `&&` while debugging so later commands do not run after vector generation fails.
