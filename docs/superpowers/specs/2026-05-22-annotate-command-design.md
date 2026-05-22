# Annotate Command Design

**Date:** 2026-05-22
**Status:** Approved
**Scope:** Add `dirtree annotate` (alias `note`) subcommand that persists per-path descriptions to `.dirtree-state` and renders them inline in the tree output.

## Motivation

Users (and LLMs working in a directory) need a way to attach short, human-readable descriptions to files and directories so subsequent `dirtree` invocations show context alongside structure. The descriptions live in the project's existing state file so they version-control alongside the code and inherit naturally down a directory tree, the same way `.gitignore` does.

## CLI Surface

```
dirtree annotate <path> "<description>"
dirtree note <path> "<description>"          # English synonym
```

- `<path>` is a relative path, with or without a `./` prefix. Leading `./` and `/` are stripped on store.
- `<description>` is a single-line string. Empty string clears the annotation locally (see "Tombstone clearing" below).
- The subcommand writes to the local `.dirtree-state` and exits. It does not render a tree.
- Multiline descriptions are rejected: if `<description>` contains `\n`, the command errors out and exits non-zero.

### Localized command names

Each locale registers one or more colloquial words for the "take a note about a file" action. English uses both `annotate` and `note`. Other locales pick whichever native term(s) best convey the colloquial "jot down a note" sense — that may be one word or two, at the locale's translator's discretion. All registered names dispatch to the same subcommand. Suggested choices (translators may refine):

| Locale | Canonical | Synonym(s) |
|--------|-----------|------------|
| en | `annotate` | `note` |
| de | `notiz` | `anmerken` |
| es | `nota` | `anotar` |
| fr | `note` | `annoter` |
| it | `nota` | `annota` |
| pt_br | `nota` | `anotar` |
| ro | `noteaza` | `adnota` |
| pl | `notatka` | `oznacz` |
| ru | `zametka` | `pometit` |
| uk | `notatka` | `poznachyty` |
| el | `simeiosi` | `simeiose` |
| tr | `not` | `notla` |
| az | `qeyd` | `nota` |
| hu | `jegyzet` | `megjegyez` |
| ar | `mulahaza` | `dawwin` |
| fa | `yaddasht` | `noteh` |
| he | `heara` | `harshom` |
| ja | `memo` | `chuushaku` |
| ko | `memo` | `juseok` |
| zh_hans | `note` | `zhushi` |
| vi | `ghichu` | `chuthich` |
| km | `kamnotsamkal` | `chamna` |

The list is advisory. Final spellings (including diacritics, native scripts, and whether to expose two synonyms or one) are decided per-locale during implementation by whoever owns that locale file; English ships with both `annotate` and `note`.

## Storage Format

A new top-level block in `.dirtree-state`, alongside `open=[...]`, `close=[...]`, `show=[...]`, `hide=[...]`:

```
annotate=[
	README.md = Project readme
	src/main.zig = Entry point, CLI arg parsing
	src/state.zig = INI-MA parser/writer
]
```

Rules:
- The block uses the same INI-MA bracket syntax as the existing collections (leading tab indent inside the block, `]` on its own line).
- Each entry is `<path> = <description>` on a single line.
- Path is everything left of the **first** `=`, trimmed of surrounding whitespace.
- Description is everything right of the first `=`, with **one** leading space stripped (so `path = value` round-trips to value `value`, not ` value`).
- No quoting. `#`, additional `=`, and other punctuation in the description are stored verbatim.
- Filenames containing `=` are not supported in v1 (documented limitation).
- On write, entries are sorted alphabetically by path for deterministic output (matching how other blocks are sorted).
- The block is omitted entirely when there are no annotation entries.

## Inheritance Semantics

`.dirtree-state` files are already walked up the directory tree to build effective state. Annotations participate in that walk:

1. Start from the deepest (target directory's) `.dirtree-state` and walk toward the root.
2. For each `.dirtree-state` encountered, merge its `annotate` entries into a map keyed by path:
   - If the path is not yet in the map, add it (whether the value is empty or not).
   - If the path is already in the map (from a deeper file), do not overwrite — deeper wins.
3. After the merge, treat entries with empty descriptions as **tombstones**: remove them from the map. They suppress ancestor annotations and produce no display output.

Net behavior:
- Deepest non-empty entry for a path is what displays.
- An explicit empty entry at any level acts as "no annotation here" — and because the deepest entry wins, a local empty value cleanly hides any ancestor annotation.

### Path Re-Basing Across Levels

Paths inside annotations are always relative to the directory containing the `.dirtree-state` file that holds the entry. When merging the inheritance chain, each ancestor entry's path must be re-expressed relative to the **target directory** (the directory dirtree is rendering):

1. Resolve the ancestor entry's path against the ancestor state-file's directory to get an absolute path.
2. Compute the path relative to the target directory.
3. If the result starts with `..` (i.e., the annotated path lies outside the rendered tree), discard the entry — it cannot match anything we render.
4. Otherwise use the re-based relative path as the map key.

Example: target dir is `/home/me/proj/sub`. Parent state file at `/home/me/proj/.dirtree-state` has `annotate=[ sub/file.txt = note A, src/main.zig = note B ]`. After re-basing:
- `sub/file.txt` → absolute `/home/me/proj/sub/file.txt` → relative-to-target `file.txt` (kept).
- `src/main.zig` → absolute `/home/me/proj/src/main.zig` → relative-to-target `../src/main.zig` (discarded, starts with `..`).

Re-basing happens once when `EffectiveState` is built; the final `annotations` map's keys are all relative to the target directory, ready for direct lookup during render.

## Rendering

When rendering an entry whose normalized relative path (relative to the target directory) is present in the effective annotations map with a non-empty value, append ` # <description>` to the line — a single space, then `#`, then a space, then the description.

```
├── src/ # Source code
├── README.md # Project readme
└── build.zig # Build script
```

- No column alignment in v1. The `#` appears immediately after whatever the previous content was (entry name, or `-> target` for symlinks).
- For symlinks rendered as `name -> target`, the annotation goes after the target: `name -> target # description`.
- Shown in all rendering modes including `--simple`.
- Annotations are unaffected by `--no-color`. They are emitted as plain text. (Coloring annotations is out of scope for v1.)

## Annotating the Current Directory

`dirtree annotate . "<description>"` and `dirtree annotate "" "<description>"` both store the entry with path `.`. When rendering, the root header line (typically the absolute or relative directory name at the top of the tree) receives the annotation in the same `name # description` form.

## Command Mode Dispatch

`annotate` (and the `note` synonym, plus localized alias entries) is recognized as the **first positional argument** after the program name. When detected:
1. Parse `<path>` (next positional arg). Required.
2. Parse `<description>` (next positional arg). Required; may be the empty string.
3. Reject any subsequent positional args (error: too many arguments).
4. Reject `<description>` containing `\n`.
5. Load the local `.dirtree-state` (if any), set/clear the annotation, write atomically (temp file + rename, same as existing `persistState`).
6. Exit 0. Do not render a tree.

Flags that come before the subcommand keyword (e.g., `dirtree --lang en annotate ...`) are accepted as usual. Flags after the subcommand keyword are not interpreted — they would be treated as the description if positionally present.

## Code Changes

| File | Change |
|------|--------|
| `src/state.zig` | Add `AnnotateEntry { path: []const u8, description: []const u8 }`. Add `annotate_entries: ArrayListUnmanaged(AnnotateEntry) = .empty` on `StateFile`. Extend the array-block parser to recognize `annotate=[` and parse `path = description` lines (distinct from the regex/glob/literal parsing in other blocks). Extend `writeStateFile` to emit the block sorted by path. Update `deinit`. |
| `src/path_eval.zig` | Add `annotations: StringHashMapUnmanaged([]const u8)` to `EffectiveState`. In `buildEffectiveState`, after the existing walk merges other state, walk the chain again (or merge during the existing walk) merging annotations deepest-first, applying tombstones. Re-base ancestor paths so they're relative to the target directory. |
| `src/main.zig` | Add subcommand dispatch at the top of `parseArgs` (or in `main` before `parseArgs`): if `args[1]` matches `annotate` / `note` / localized form, run the annotate flow (path + description, write, exit). Add `annotate` to the localized alias map. Reuse `persistState` infrastructure where possible. |
| `src/tree_render.zig` | At the points that finish writing a single line for an entry (after the name, after symlink target), look up the path in `effective.annotations` and append ` # <desc>` if present. Apply to both the root header line and child entries. |
| `src/i18n/mod.zig` and locale files | Extend the alias map to support positional subcommand names (currently `--flag` style only). Add `annotate` arg id. Each locale file lists its colloquial subcommand names — `en.zig` lists both `annotate` and `note`; other locales list whichever native terms convey "take a note about a file" (see "Localized command names" table). Add help text strings (subcommand description). Add error strings: `err_annotate_requires_path`, `err_annotate_requires_description`, `err_annotate_multiline`, `err_annotate_too_many_args`. |
| `src/main.zig` printHelp | Add a line describing the `annotate` / `note` subcommand. |
| `test/dirtree_test` | Integration tests covering: set annotation; clear annotation locally; inherited annotation from parent state file; local override of parent annotation; empty-string tombstone hides parent annotation; rendering format; multiline rejected; rendering with `--simple`. |
| Unit tests in `state.zig` | Parse/write round-trip for `annotate=[ ... ]`. Empty description preserved as empty value. Sorting on write. |
| Unit tests in `path_eval.zig` | Merge with inheritance: deeper overrides shallower; tombstone suppresses ancestor; absent local entry inherits from ancestor. |

## Edge Cases

- **Annotating a path that does not exist on disk**: allowed. The annotation persists but never displays until a matching entry appears.
- **Path with `=`**: not supported; the parser will split on the first `=` and the path side will contain trailing characters before `=`. Documented limitation.
- **Description with leading `#`**: stored and displayed verbatim. Will render as ` # # actual description` — this is acceptable; user opted in.
- **Description with trailing whitespace**: trailing whitespace is preserved in storage but rendering does not strip it (annotations are short single lines; users are expected to provide clean input).
- **Description containing `]` on its own**: stored inline on the same line as the path, so the parser only treats `]` on its own line as the block close. No special handling needed.
- **Concurrent invocations**: the existing atomic temp-file + rename pattern handles this.

## Out of Scope (Future Work)

- Column alignment of `#` markers across siblings.
- Multiline annotations.
- A `--no-annotations` display flag.
- Per-annotation color or style.
- An explicit "remove from local file" verb separate from the tombstone-clear behavior.
- Bulk operations (annotate many paths at once).
- Validation that the annotated path exists.

## Testing Strategy

Per project TDD policy (CLAUDE.md), each new behavior gets a failing test before implementation:
1. **Parser test** (`state.zig`): parse `annotate=[\n\tfoo = bar\n]` and verify `annotate_entries` is populated correctly.
2. **Writer test** (`state.zig`): build a `StateFile` with annotate entries, write it, parse back, verify equality.
3. **Inheritance test** (`path_eval.zig`): build two parent/child `.dirtree-state` files, verify deeper overrides shallower and tombstones suppress.
4. **CLI test** (`test/dirtree_test`): `dirtree annotate src/main.zig "Entry"` then `dirtree` shows the annotation; `dirtree annotate src/main.zig ""` clears it.
5. **Render test** (`tree_render.zig` or integration): annotated entry produces ` # description` suffix on the correct line.
