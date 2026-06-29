# RULES — invariants that must never be violated without an excellent reason

These are hard constraints for `dirtree`. Breaking one needs an explicit,
documented justification (and usually a conversation with Peter).

1. **No data loss.** Never `rm` user files. Annotations/state are edited through
   the CLI; deletions go to `~/.Trash/`. The `.dirtree-state` format preserves
   unknown keys as passthrough — never silently drop them.

2. **`.dirtree-state` round-trips.** parse → serialize → re-parse must preserve
   every field (scalars, entry sets, annotations, passthrough). Serialization is
   a fixed point (writing twice is byte-identical). Guarded by a structural
   round-trip unit test.

3. **An empty annotation is a tombstone, not a clear-to-nothing bug.** `note PATH ""`
   intentionally suppresses an inherited parent-dir note. Do not "fix" it to delete
   the entry outright.

4. **i18n completeness is compile-enforced.** Every user-facing string exists in all
   50 locales; a missing field must fail the build, never fall back silently to
   English. CLI/arg aliases are localized in their own language only (not translated
   into every locale). Bilingual errors: localized message + English original in
   parens with a "(search for: …)" hint.

5. **No `--head`/`--tail`.** Removed deliberately — unix `head`/`tail` cover it and
   the tool stays focused. Do not reintroduce them; the large-output warning must
   suggest `--depth`/`--hide`, never the removed flags.

6. **Native Zig CLI — no C FFI here.** A deliberate, Peter-approved deviation from
   the fleet-wide "Zig core + C FFI + C CLI" pattern. Do not add an FFI boundary to
   this project after a context wipe.

7. **TDD for all behavioral work.** Failing test first → minimal code → green. Bug
   reports start with a reproducing failing test, not speculative edits.

8. **Tests run clean.** No stray stderr in a passing run; expected stderr is captured
   and asserted on. Filters are tested as classifiers over sets, not single examples.

9. **Cross-platform always.** Code targets all 5 OS/arch combos. Don't use APIs that
   only work on the dev machine (e.g. POSIX-only env access where Windows needs
   `std.process.getEnvVarOwned`).

10. **jj only — never raw `git`.** SCM goes through `jj` (with `jj git push/fetch`
    for GitHub). `gh` is fine for PRs/issues/releases. Commit messages carry **no**
    AI attribution (enforced by a pre-commit hook).

11. **Build via the top-level scripts.** Use `./build` / `./run-tests` (nix-sandboxed).
    Do not `nix develop -c zig build` for native builds (Zig's bundled libSystem
    stubs don't cover current macOS).

12. **Numeric args reject negatives and overflow.** `-d`/`--max-lines` exit non-zero
    on negative or out-of-range (u32) values.
