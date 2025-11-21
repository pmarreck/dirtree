# PROJECT PLAN

## Context Snapshot (Nov 21, 2025)
- Working tree dirty (tests tweaked); latest commit: `tests: banner shows ape path via wrapper` (c80c8b6) plus earlier test refactors.
- Banner now logs once: `Using /home/pmarreck/Documents/printable-binary/bin/printable_binary_ape.com as printable_binary executable via wrapper /home/pmarreck/Documents/printable-binary/bin/printable_binary`.
- All tests currently pass: `./test/dirtree_test` ~10–12s runtime using APE printable_binary.
- Printable capture helpers: `capture_command_printable`, `capture_dirtree_printable`, `capture_dirtree_test_printable`, `capture_dirtree_printable_outputs`; reusable fixtures `fixture_simple_tree` and `fixture_decorated_single_file` clear `.dirtree-state` between uses.

## Remaining TODOs
1) Expand reusable fixture approach where safe to trim setup time (e.g., hide/show/decorated clusters), ensuring state files are cleaned between uses (see `fixture_simple_tree` / `fixture_decorated_single_file`).
2) Keep banners single-line; ensure PRINTABLE_BACKING_BIN set before calling `print_printable_banner` (already done; derivation uses wrapper dir if unset).

## Notes
- USE_WASM defaults to false in `.envrc`; APE binary is used in tests.
- Test helper `print_printable_banner` is invoked when `PRINTABLE_BINARY_BIN` is resolved.
- Avoid reintroducing tmp files; use printable captures and compare_printable.
- Repo is clean right now; commits so far in this streak: 
  - c80c8b6 tests: banner shows ape path via wrapper
  - 00ffeeb tests: combine printable_binary banner into single line
  - 2d1a97b tests: move hide regex cases to printable captures
  - 094bebd tests: finish printable captures for regex/hide/simple envs
  - b7f3b47 tests: convert inline/simple/env cases to printable captures
