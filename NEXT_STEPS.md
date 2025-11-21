# Next Steps

1. Extend reusable fixture helpers (starting with `fixture_simple_tree`) to more clusters where safe, ensuring .dirtree-state files get cleared between uses.
2. Prefer the printable helpers (`capture_command_printable`, `capture_dirtree_printable`, `capture_printable_outputs`, `capture_dirtree_test_printable`) for new tests; avoid temp files unless absolutely needed.
3. When implementing new features, add printable_binary regression coverage as part of the change so future toggles stay guarded.
