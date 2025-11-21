# PROJECT PLAN

## Context Snapshot (Nov 21, 2025)
- Working tree clean; latest commit: `tests: banner shows ape path via wrapper` (c80c8b6) plus earlier test refactors.
- Banner now logs once: `Using /home/pmarreck/Documents/printable-binary/bin/printable_binary_ape.com as printable_binary executable via wrapper /home/pmarreck/Documents/printable-binary/bin/printable_binary`.
- All tests pass: `test/dirtree_test` ~10–12s runtime using APE printable_binary.
- Printable capture helpers: `capture_command_printable`, `capture_dirtree_printable`, `print_printable_banner` defined in `test/dirtree_test`.

## Remaining TODOs
1) Convert remaining `run_and_capture` uses to printable in-memory capture (remove temp files):
   - Locations (as of now, via `rg run_and_capture`): 485, 958, 2405, 2434, 2460, 2485, 2509, 2535, 2563, 2588, 2614, 2642, 2670 in `test/dirtree_test`.
   - These correspond to hide-dot/show-hidden/decorated clusters, show-hidden/decorated/no-icons/PIPED_STDOUT/--no-hyperlinks etc.
2) After conversions, drop the “Pending in-memory refactors” header list and consider removing `run_and_capture` helper if unused.
3) Keep banners single-line; ensure PRINTABLE_BACKING_BIN set before calling `print_printable_banner` (already done; derivation uses wrapper dir if unset).

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

